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

// File dedup episode yang sudah dikirim (bukan pengaturan grup)
const FILE_DATA  = path.join(process.cwd(), 'data', 'infowibu.json');
// File konfigurasi utama bot — pengaturan grup disimpan di sini
const FILE_CONFIG = path.join(process.cwd(), 'config.json');

// Alamat API AniList
const URL_ANILIST = 'https://graphql.anilist.co';

// ── FUNGSI BACA & SIMPAN DATA DEDUP ──────────────────────────────────────────

// Hanya menyimpan daftar ID episode yang sudah dikirim (dedup)
function bacaData() {
    try {
        if (fs.existsSync(FILE_DATA)) {
            return JSON.parse(fs.readFileSync(FILE_DATA, 'utf-8'));
        }
    } catch (_) {}
    return { idTerkirim: [] };
}

function simpanData(data) {
    try {
        fs.writeFileSync(FILE_DATA, JSON.stringify(data, null, 2), 'utf-8');
    } catch (_) {}
}

// ── BACA & SIMPAN CONFIG.JSON ─────────────────────────────────────────────────

function bacaConfig() {
    try {
        if (fs.existsSync(FILE_CONFIG)) {
            return JSON.parse(fs.readFileSync(FILE_CONFIG, 'utf-8'));
        }
    } catch (_) {}
    return {};
}

function simpanConfig(cfg) {
    try {
        fs.writeFileSync(FILE_CONFIG, JSON.stringify(cfg, null, 2), 'utf-8');
    } catch (_) {}
}

// ── PENGATURAN GRUP (DISIMPAN DI CONFIG.JSON) ─────────────────────────────────

// Aktifkan atau nonaktifkan infowibu di sebuah grup
function aturGrup(jidGrup, aktif) {
    const cfg = bacaConfig();
    if (!cfg.infowibu)              cfg.infowibu         = { enabled: true, groups: {} };
    if (!cfg.infowibu.groups)       cfg.infowibu.groups  = {};
    cfg.infowibu.groups[jidGrup]    = { enabled: aktif, diubahPada: Date.now() };
    simpanConfig(cfg);
}

// Cek apakah infowibu aktif di grup tertentu
function cekGrupAktif(jidGrup) {
    const cfg = bacaConfig();
    return !!(cfg.infowibu?.groups?.[jidGrup]?.enabled);
}

// Ambil daftar semua grup yang sudah diaktifkan
function daftarGrupAktif() {
    const cfg = bacaConfig();
    return Object.entries(cfg.infowibu?.groups || {})
        .filter(([, v]) => v.enabled)
        .map(([jid]) => jid);
}

// Ambil semua pengaturan grup (aktif maupun tidak) dari config.json
function semuaPengaturanGrup() {
    return bacaConfig().infowibu?.groups || {};
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
        seasonInt
        status
        nextAiringEpisode { episode airingAt timeUntilAiring }
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

// ── TERJEMAHAN OTOMATIS KE BAHASA INDONESIA ──────────────────────────────────

// Terjemahkan teks ke Bahasa Indonesia menggunakan Google Translate gratis
async function terjemahkan(teks) {
    if (!teks || !teks.trim()) return teks;
    try {
        const url    = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=id&dt=t&q=${encodeURIComponent(teks)}`;
        const { data } = await axios.get(url, { timeout: 8000 });
        // Hasil terjemahan ada di data[0] berupa array array
        if (Array.isArray(data) && Array.isArray(data[0])) {
            return data[0].map(seg => seg?.[0] || '').join('').trim() || teks;
        }
    } catch (_) {}
    // Kalau terjemahan gagal, kembalikan teks asli
    return teks;
}

// Bersihkan teks deskripsi dari tag HTML & spasi berlebih
function bersihkanDeskripsi(teks, maks = 250) {
    let hasil = (teks || '')
        .replace(/<br\s*\/?>/gi, '\n')
        .replace(/<[^>]+>/g, '')
        .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
        .replace(/\n{3,}/g, '\n\n')
        .trim()
        .slice(0, maks);
    if ((teks || '').replace(/<[^>]+>/g, '').trim().length > maks) hasil += '...';
    return hasil;
}

// ── PETA GENRE & MUSIM KE BAHASA INDONESIA ───────────────────────────────────

const PETA_GENRE = {
    'Action'          : 'Aksi',
    'Adventure'       : 'Petualangan',
    'Comedy'          : 'Komedi',
    'Drama'           : 'Drama',
    'Ecchi'           : 'Ecchi',
    'Fantasy'         : 'Fantasi',
    'Horror'          : 'Horor',
    'Mahou Shoujo'    : 'Sihir',
    'Mecha'           : 'Mecha',
    'Music'           : 'Musik',
    'Mystery'         : 'Misteri',
    'Psychological'   : 'Psikologi',
    'Romance'         : 'Romansa',
    'Sci-Fi'          : 'Fiksi Ilmiah',
    'Slice of Life'   : 'Kehidupan Sehari-hari',
    'Sports'          : 'Olahraga',
    'Supernatural'    : 'Supranatural',
    'Thriller'        : 'Thriller',
    'Hentai'          : 'Dewasa',
    'Shounen'         : 'Shounen',
    'Shoujo'          : 'Shoujo',
    'Seinen'          : 'Seinen',
    'Josei'           : 'Josei',
};

const PETA_MUSIM = {
    'SPRING' : 'Musim Semi',
    'SUMMER' : 'Musim Panas',
    'FALL'   : 'Musim Gugur',
    'WINTER' : 'Musim Dingin',
};

// Terjemahkan daftar genre ke Bahasa Indonesia
function terjemahkanGenre(daftarGenre) {
    return (daftarGenre || [])
        .slice(0, 4)
        .map(g => PETA_GENRE[g] || g)
        .join(', ') || '-';
}

// Terjemahkan nama musim ke Bahasa Indonesia
function terjemahkanMusim(season, year) {
    if (!season) return '-';
    const namaMusim = PETA_MUSIM[String(season).toUpperCase()] || kapitalisasi(season);
    return year ? `${namaMusim} ${year}` : namaMusim;
}

// Terjemahkan status tayang anime ke Bahasa Indonesia
const PETA_STATUS = {
    'RELEASING'        : 'Sedang Tayang',
    'FINISHED'         : 'Tamat',
    'NOT_YET_RELEASED' : 'Belum Tayang',
    'CANCELLED'        : 'Dibatalkan',
    'HIATUS'           : 'Hiatus',
};
function terjemahkanStatus(status) {
    return PETA_STATUS[String(status || '').toUpperCase()] || status || '-';
}

// Buat progress bar episode — contoh: ▓▓▓▓▓░░░░░ 5/12
function buatProgressBar(sekarang, total, panjang = 10) {
    if (!total || total <= 0) return '';
    const isi    = Math.round((sekarang / total) * panjang);
    const kosong = panjang - isi;
    const bar    = '▓'.repeat(Math.max(0, isi)) + '░'.repeat(Math.max(0, kosong));
    return `[${bar}] ${sekarang}/${total}`;
}

// ── FORMAT CAPTION REALTIME (NOTIF EPISODE BARU) ──────────────────────────────

// Fungsi ini async karena perlu terjemah sinopsis ke Bahasa Indonesia
async function buatCaptionEpisode(item) {
    const a      = item.anime;
    const judul  = a.title?.romaji || a.title?.english || a.title?.native || '?';
    const native = a.title?.native ? ` _(${a.title.native})_` : '';
    const skor   = a.averageScore  ? `⭐ ${(a.averageScore / 10).toFixed(1)}/10` : '⭐ -';
    const genre  = terjemahkanGenre(a.genres);
    const studio = a.studios?.nodes?.[0]?.name || '-';
    const musim  = terjemahkanMusim(a.season, a.seasonYear);

    // Info progress episode — "Ep 5 dari 12 (41%)" atau "Ep 5 (sedang tayang)"
    const totalEps   = a.episodes || 0;
    const epSekarang = item.episode;
    const progresBar = totalEps > 0 ? buatProgressBar(epSekarang, totalEps) : '';
    const persen     = totalEps > 0 ? ` (${Math.round((epSekarang / totalEps) * 100)}%)` : '';
    const infoEp     = totalEps > 0
        ? `*Ep ${epSekarang} dari ${totalEps}*${persen}\n${progresBar}`
        : `*Ep ${epSekarang}* _(total episode belum ditentukan)_`;

    // Info episode berikutnya — "Ep 6 tayang: Sabtu, 17 Mei 2026 pukul 23:30 WIB"
    let epBerikutnya = '';
    if (a.nextAiringEpisode) {
        const nEp  = a.nextAiringEpisode.episode;
        const wkt  = new Date(a.nextAiringEpisode.airingAt * 1000);
        const tgl  = wkt.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
        const jam  = wkt.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Jakarta' });
        epBerikutnya = `\n📅 *Ep ${nEp} tayang:* ${tgl} pukul ${jam} WIB`;
    }

    // Status tayang dalam Bahasa Indonesia
    const statusIndo = terjemahkanStatus(a.status);

    // Bersihkan lalu terjemahkan sinopsis ke Bahasa Indonesia
    const deskripsiAsli = bersihkanDeskripsi(a.description, 300);
    const deskripsi     = await terjemahkan(deskripsiAsli);

    const waktuKirim = new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });

    return (
        `🔴 *REALTIME INFO WIBU — EPISODE BARU!*\n` +
        `${'━'.repeat(30)}\n\n` +
        `🎌 *${judul}*${native}\n` +
        `${'─'.repeat(28)}\n` +
        `📺 *EPISODE TERBARU*\n` +
        `${infoEp}${epBerikutnya}\n\n` +
        `📖 *Sinopsis:*\n${deskripsi}\n\n` +
        `${'─'.repeat(28)}\n` +
        `${skor}  |  🎭 ${genre}\n` +
        `🏢 Studio   : *${studio}*\n` +
        `🗓️ Musim    : *${musim}*\n` +
        `📡 Status   : *${statusIndo}*\n\n` +
        `🔗 ${a.siteUrl || 'https://anilist.co'}\n` +
        `${'━'.repeat(30)}\n` +
        `🕐 _${waktuKirim} WIB_`
    );
}

// Format caption untuk trending (simulasi & fallback) — juga async
async function buatCaption(post, opsi = {}) {
    const { realtime = true } = opsi;
    const a      = post.anime;
    const judul  = a.title?.romaji || a.title?.english || a.title?.native || '?';
    const native = a.title?.native ? ` _(${a.title.native})_` : '';
    const skor   = a.averageScore  ? `⭐ ${(a.averageScore / 10).toFixed(1)}/10` : '⭐ -';
    const genre  = terjemahkanGenre(a.genres);
    const studio = a.studios?.nodes?.[0]?.name || '-';
    const eps    = a.episodes ? `${a.episodes} eps` : 'Belum selesai';

    const deskripsiAsli = bersihkanDeskripsi(a.description, 300);
    const deskripsi     = await terjemahkan(deskripsiAsli);

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
        `📖 *Sinopsis:*\n${deskripsi}\n\n` +
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
            caption  : await buatCaptionEpisode(post),
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
        caption  : await buatCaption(post, { realtime: true }),
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
