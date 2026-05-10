'use strict';

/**
 * ─────────────────────────────────────────────────────
 *  FITUR   : Info Wibu Realtime
 *  Fungsi  : Pantau jadwal tayang anime dari AniList
 *            setiap 5 menit. Langsung kirim notifikasi
 *            ke grup WA saat ada episode baru tayang.
 *  Sumber  : AniList GraphQL API (gratis, tanpa login)
 * ─────────────────────────────────────────────────────
 */

const axios = require('axios');
const fs    = require('fs');
const path  = require('path');

// Lokasi file penyimpanan data (grup aktif, episode sudah dikirim, dll)
const FILE_DATA = path.join(process.cwd(), 'data', 'infowibu.json');

// Alamat API AniList
const URL_ANILIST = 'https://graphql.anilist.co';

// ── FUNGSI BACA & SIMPAN DATA ─────────────────────────────────────────────────

function bacaData() {
    try {
        if (fs.existsSync(FILE_DATA)) {
            return JSON.parse(fs.readFileSync(FILE_DATA, 'utf-8'));
        }
    } catch (_) {}
    return { grup: {}, idTerkirim: [], waktuCekTerakhir: 0 };
}

function simpanData(data) {
    try {
        fs.writeFileSync(FILE_DATA, JSON.stringify(data, null, 2), 'utf-8');
    } catch (_) {}
}

// ── PENGATURAN GRUP ───────────────────────────────────────────────────────────

// Aktifkan atau nonaktifkan infowibu di sebuah grup
function aturGrup(jidGrup, aktif) {
    const data = bacaData();
    if (!data.grup) data.grup = {};
    data.grup[jidGrup] = { aktif, diubahPada: Date.now() };
    simpanData(data);
}

// Cek apakah infowibu aktif di grup tertentu
function cekGrupAktif(jidGrup) {
    const data = bacaData();
    return !!(data.grup?.[jidGrup]?.aktif);
}

// Ambil daftar semua grup yang sudah diaktifkan
function daftarGrupAktif() {
    const data = bacaData();
    return Object.entries(data.grup || {})
        .filter(([, v]) => v.aktif)
        .map(([jid]) => jid);
}

// Ambil semua pengaturan grup (aktif maupun tidak)
function semuaPengaturanGrup() {
    return bacaData().grup || {};
}

// ── PENCEGAH KIRIMAN DUPLIKAT ─────────────────────────────────────────────────

// Tandai episode sudah pernah dikirim supaya tidak dikirim dua kali
function tandaiSudahKirim(idUnik) {
    const data = bacaData();
    if (!data.idTerkirim) data.idTerkirim = [];
    // Simpan maksimal 500 ID terakhir
    data.idTerkirim = [String(idUnik), ...data.idTerkirim].slice(0, 500);
    simpanData(data);
}

// Cek apakah episode ini sudah pernah dikirim
function sudahPernahKirim(idUnik) {
    const data = bacaData();
    return (data.idTerkirim || []).includes(String(idUnik));
}

// Simpan waktu terakhir cek jadwal tayang
function simpanWaktuCek() {
    const data = bacaData();
    data.waktuCekTerakhir = Math.floor(Date.now() / 1000);
    simpanData(data);
}

// ── QUERY REALTIME: CEK JADWAL TAYANG ────────────────────────────────────────

// Query ini ambil episode yang tayang dalam rentang waktu tertentu
const QUERY_JADWAL_TAYANG = `
query ($dari: Int, $sampai: Int) {
  Page(perPage: 50) {
    airingSchedules(airingAt_greater: $dari, airingAt_lesser: $sampai, notYetAired: false) {
      episode
      airingAt
      media {
        id
        title { romaji native english }
        description(asHtml: false)
        episodes
        averageScore
        popularity
        genres
        coverImage { extraLarge large }
        bannerImage
        siteUrl
        studios(isMain: true) { nodes { name } }
        season
        seasonYear
        status
      }
    }
  }
}`;

// Ambil daftar episode yang baru saja tayang dalam rentang waktu (detik Unix)
async function cekEpisodeBaruTayang(dariDetik, sampaiDetik) {
    const { data } = await axios.post(
        URL_ANILIST,
        {
            query: QUERY_JADWAL_TAYANG,
            variables: { dari: dariDetik, sampai: sampaiDetik },
        },
        {
            headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
            timeout: 15000,
        }
    );
    return data?.data?.Page?.airingSchedules || [];
}

// ── QUERY TRENDING: FALLBACK / SIMULASI ──────────────────────────────────────

// Query anime trending (dipakai untuk simulasi & fallback)
const QUERY_ANIME_TRENDING = `
query ($halaman: Int, $jumlah: Int) {
  Page(page: $halaman, perPage: $jumlah) {
    media(sort: TRENDING_DESC, type: ANIME, status: RELEASING) {
      id
      title { romaji native english }
      description(asHtml: false)
      episodes
      status
      season
      seasonYear
      averageScore
      popularity
      genres
      coverImage { extraLarge large }
      bannerImage
      siteUrl
      studios(isMain: true) { nodes { name } }
      nextAiringEpisode { episode airingAt }
    }
  }
}`;

async function ambilAnimeTrending(halaman = 1, jumlah = 10) {
    const { data } = await axios.post(
        URL_ANILIST,
        { query: QUERY_ANIME_TRENDING, variables: { halaman, jumlah } },
        {
            headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
            timeout: 15000,
        }
    );
    return data?.data?.Page?.media || [];
}

// ── CARI EPISODE BARU YANG BELUM PERNAH DIKIRIM ──────────────────────────────

// Digunakan scheduler realtime — cek episode yang tayang 5 menit terakhir
async function cariEpisodeBaru(rentangMenit = 5) {
    const sekarang  = Math.floor(Date.now() / 1000);
    const dariDetik = sekarang - (rentangMenit * 60); // mundur N menit
    const jadwal    = await cekEpisodeBaruTayang(dariDetik, sekarang);

    const hasilBaru = [];
    for (const item of jadwal) {
        // Buat ID unik dari kombinasi ID anime + nomor episode
        const idUnik = `ep-${item.media?.id}-${item.episode}`;
        if (sudahPernahKirim(idUnik)) continue; // Lewati yang sudah dikirim
        if (!item.media) continue;
        hasilBaru.push({ episode: item.episode, tayangPada: item.airingAt, anime: item.media, idUnik });
    }

    return hasilBaru;
}

// ── FORMAT CAPTION REALTIME (NOTIF EPISODE BARU) ──────────────────────────────

function buatCaptionEpisode(item) {
    const a      = item.anime;
    const judul  = a.title?.romaji || a.title?.english || a.title?.native || '?';
    const native = a.title?.native ? ` _(${a.title.native})_` : '';
    const skor   = a.averageScore  ? `⭐ ${(a.averageScore / 10).toFixed(1)}/10` : '⭐ -';
    const genre  = (a.genres || []).slice(0, 4).join(', ') || '-';
    const studio = a.studios?.nodes?.[0]?.name || '-';
    const musim  = a.season && a.seasonYear ? `${kapitalisasi(a.season)} ${a.seasonYear}` : '-';

    // Potong deskripsi agar tidak terlalu panjang
    let deskripsi = (a.description || '')
        .replace(/<[^>]+>/g, '')
        .replace(/\n{3,}/g, '\n\n')
        .trim()
        .slice(0, 220);
    if ((a.description || '').length > 220) deskripsi += '...';

    const waktuKirim = new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });
    const totalEps   = a.episodes ? `/${a.episodes}` : '';

    return (
        `🔴 *REALTIME INFO WIBU — EPISODE BARU!*\n` +
        `${'━'.repeat(30)}\n\n` +
        `🎌 *${judul}*${native}\n` +
        `📺 *Episode ${item.episode}${totalEps} baru saja tayang!*\n\n` +
        `📖 ${deskripsi}\n\n` +
        `${skor}  |  🎭 ${genre}\n` +
        `🏢 Studio : *${studio}*\n` +
        `🗓️ Musim  : *${musim}*\n\n` +
        `🔗 ${a.siteUrl || 'https://anilist.co'}\n` +
        `${'━'.repeat(30)}\n` +
        `🕐 _${waktuKirim} WIB_`
    );
}

// Format caption untuk trending (simulasi & fallback)
function buatCaption(post, opsi = {}) {
    const { realtime = true } = opsi;
    const a      = post.anime;
    const judul  = a.title?.romaji || a.title?.english || a.title?.native || '?';
    const native = a.title?.native ? ` _(${a.title.native})_` : '';
    const skor   = a.averageScore  ? `⭐ ${(a.averageScore / 10).toFixed(1)}/10` : '⭐ -';
    const genre  = (a.genres || []).slice(0, 4).join(', ') || '-';
    const studio = a.studios?.nodes?.[0]?.name || '-';
    const eps    = a.episodes ? `${a.episodes} eps` : 'Belum selesai';

    let deskripsi = (a.description || '')
        .replace(/<[^>]+>/g, '')
        .replace(/\n{3,}/g, '\n\n')
        .trim()
        .slice(0, 200);
    if ((a.description || '').length > 200) deskripsi += '...';

    let infoEpSelanjutnya = '';
    if (a.nextAiringEpisode) {
        const nomorEp     = a.nextAiringEpisode.episode;
        const waktuTayang = new Date(a.nextAiringEpisode.airingAt * 1000);
        const tanggal     = waktuTayang.toLocaleDateString('id-ID', {
            weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
        });
        infoEpSelanjutnya = `\n📅 *Ep ${nomorEp} tayang:* ${tanggal}`;
    }

    const badge      = realtime ? '🔴 *REALTIME INFO WIBU*' : '📢 *INFO WIBU*';
    const waktuKirim = new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });

    return (
        `${badge}\n` +
        `${'─'.repeat(28)}\n` +
        `🎌 *${judul}*${native}\n\n` +
        `📖 ${deskripsi}\n\n` +
        `${skor}  |  🎭 ${genre}\n` +
        `🏢 Studio: *${studio}*\n` +
        `📺 Episode: *${eps}*${infoEpSelanjutnya}\n\n` +
        `🔗 ${a.siteUrl || 'https://anilist.co'}\n` +
        `${'─'.repeat(28)}\n` +
        `🕐 _${waktuKirim} WIB_`
    );
}

// ── FUNGSI BANTU ──────────────────────────────────────────────────────────────

function kapitalisasi(str) {
    return String(str || '').toLowerCase().replace(/^\w/, c => c.toUpperCase());
}

// Ambil URL gambar terbaik (banner > cover besar > cover kecil)
function ambilUrlGambar(post) {
    const a = post.anime || post;
    return a.bannerImage || a.coverImage?.extraLarge || a.coverImage?.large || null;
}

// ── SIMULASI / TES KIRIM ──────────────────────────────────────────────────────

// Simulasi realtime: cek jadwal tayang 24 jam ke belakang supaya pasti ada data
async function simulasi() {
    // Coba cek jadwal 24 jam ke belakang untuk simulasi
    const sekarang  = Math.floor(Date.now() / 1000);
    const dariDetik = sekarang - (24 * 60 * 60); // 24 jam ke belakang
    const jadwal    = await cekEpisodeBaruTayang(dariDetik, sekarang);

    if (jadwal.length > 0) {
        // Pakai episode terbaru yang ditemukan
        const item   = jadwal[jadwal.length - 1];
        const post   = { episode: item.episode, tayangPada: item.airingAt, anime: item.media, idUnik: `ep-${item.media?.id}-${item.episode}` };
        return {
            caption  : buatCaptionEpisode(post),
            urlGambar: ambilUrlGambar(post),
            judul    : item.media?.title?.romaji || item.media?.title?.english || '?',
            idUnik   : post.idUnik,
            tipe     : 'realtime-episode',
        };
    }

    // Fallback ke trending kalau tidak ada jadwal
    const daftar = await ambilAnimeTrending(1, 5);
    if (!daftar.length) throw new Error('Tidak ada data anime dari AniList. Coba lagi nanti.');
    const anime = daftar[0];
    const post  = { sumber: 'anilist', anime, idUnik: `al-${anime.id}` };
    return {
        caption  : buatCaption(post, { realtime: true }),
        urlGambar: ambilUrlGambar(post),
        judul    : anime.title?.romaji || anime.title?.english || '?',
        idUnik   : post.idUnik,
        tipe     : 'trending-fallback',
    };
}

// ── EKSPOR FUNGSI ─────────────────────────────────────────────────────────────

module.exports = {
    bacaData,
    simpanData,
    aturGrup,
    cekGrupAktif,
    daftarGrupAktif,
    semuaPengaturanGrup,
    tandaiSudahKirim,
    sudahPernahKirim,
    simpanWaktuCek,
    cekEpisodeBaruTayang,
    ambilAnimeTrending,
    cariEpisodeBaru,
    buatCaptionEpisode,
    buatCaption,
    ambilUrlGambar,
    simulasi,

    // Alias nama lama supaya bagian lain bot tidak error
    setGroupEnabled    : aturGrup,
    isGroupEnabled     : cekGrupAktif,
    getEnabledGroups   : daftarGrupAktif,
    getAllGroupSettings : semuaPengaturanGrup,
    markSent           : tandaiSudahKirim,
    alreadySent        : sudahPernahKirim,
    fetchTrendingAnime : ambilAnimeTrending,
    fetchFreshPost     : async () => {
        const hasil = await module.exports.cariEpisodeBaru(360); // fallback 6 jam
        return hasil?.[0] ? { anime: hasil[0].anime, uid: hasil[0].idUnik, ...hasil[0] } : null;
    },
    formatCaption      : buatCaption,
    getCoverUrl        : ambilUrlGambar,
    simulate           : simulasi,
};
