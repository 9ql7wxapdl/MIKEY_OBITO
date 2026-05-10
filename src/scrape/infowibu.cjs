'use strict';

/**
 * ─────────────────────────────────────────
 *  FITUR  : Info Wibu Otomatis
 *  Fungsi : Ambil info anime trending dari
 *           AniList lalu kirim ke grup WA
 *           secara otomatis & realtime
 * ─────────────────────────────────────────
 */

const axios = require('axios');
const fs    = require('fs');
const path  = require('path');

// Lokasi file penyimpanan data infowibu (grup aktif, anime sudah terkirim, dll)
const FILE_DATA = path.join(process.cwd(), 'data', 'infowibu.json');

// Alamat API AniList (GraphQL) — sumber data anime trending
const URL_ANILIST = 'https://graphql.anilist.co';

// Header standar untuk request HTTP
const HEADER_STANDAR = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept'    : 'application/json',
};

// ── FUNGSI BACA & SIMPAN DATA ─────────────────────────────────────────────────

// Baca data dari file JSON lokal
function bacaData() {
    try {
        if (fs.existsSync(FILE_DATA)) {
            return JSON.parse(fs.readFileSync(FILE_DATA, 'utf-8'));
        }
    } catch (_) {}
    // Kalau belum ada file, kembalikan data kosong
    return { grup: {}, idTerkirim: [], waktuAmbilTerakhir: 0 };
}

// Simpan data ke file JSON lokal
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

// Tandai sebuah anime sudah pernah dikirim (supaya tidak dikirim dua kali)
function tandaiSudahKirim(id) {
    const data = bacaData();
    if (!data.idTerkirim) data.idTerkirim = [];
    // Simpan maksimal 200 ID terakhir supaya file tidak membengkak
    data.idTerkirim = [String(id), ...data.idTerkirim].slice(0, 200);
    simpanData(data);
}

// Cek apakah anime sudah pernah dikirim sebelumnya
function sudahPernahKirim(id) {
    const data = bacaData();
    return (data.idTerkirim || []).includes(String(id));
}

// ── QUERY GRAPHQL KE ANILIST ──────────────────────────────────────────────────

// Query ini mengambil daftar anime yang sedang tayang & paling trending
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

// Ambil daftar anime trending dari AniList
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

// ── AMBIL ANIME BARU YANG BELUM PERNAH DIKIRIM ───────────────────────────────

async function ambilAnimeBaru() {
    // Coba halaman pertama dulu
    const daftar1 = await ambilAnimeTrending(1, 20);
    for (const anime of daftar1) {
        const idUnik = `al-${anime.id}`;
        if (sudahPernahKirim(idUnik)) continue; // Lewati yang sudah dikirim
        return { sumber: 'anilist', anime, idUnik };
    }

    // Kalau halaman pertama sudah habis semua, coba halaman kedua
    const daftar2 = await ambilAnimeTrending(2, 20);
    for (const anime of daftar2) {
        const idUnik = `al-${anime.id}`;
        if (sudahPernahKirim(idUnik)) continue;
        return { sumber: 'anilist', anime, idUnik };
    }

    // Tidak ada anime baru yang belum dikirim
    return null;
}

// ── FORMAT TEKS CAPTION ───────────────────────────────────────────────────────

function buatCaption(post, opsi = {}) {
    const { realtime = true } = opsi;
    const a = post.anime;

    // Judul: utamakan romaji, lalu inggris, lalu native
    const judul       = a.title?.romaji || a.title?.english || a.title?.native || '?';
    const judulNative = a.title?.native ? ` _(${a.title.native})_` : '';

    // Skor dari AniList (skala 0–100 diubah jadi 0–10)
    const skor   = a.averageScore ? `⭐ ${(a.averageScore / 10).toFixed(1)}/10` : '⭐ -';
    const genre  = (a.genres || []).slice(0, 4).join(', ') || '-';
    const studio = a.studios?.nodes?.[0]?.name || '-';
    const eps    = a.episodes ? `${a.episodes} eps` : 'Belum selesai';

    // Potong deskripsi maksimal 200 karakter supaya tidak terlalu panjang
    let deskripsi = (a.description || '')
        .replace(/<[^>]+>/g, '')      // Hapus tag HTML
        .replace(/\n{3,}/g, '\n\n')   // Rapikan baris kosong berlebihan
        .trim()
        .slice(0, 200);
    if ((a.description || '').length > 200) deskripsi += '...';

    // Info episode berikutnya (kalau ada)
    let infoEpSelanjutnya = '';
    if (a.nextAiringEpisode) {
        const nomorEp  = a.nextAiringEpisode.episode;
        const waktuTayang = new Date(a.nextAiringEpisode.airingAt * 1000);
        const tanggal = waktuTayang.toLocaleDateString('id-ID', {
            weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
        });
        infoEpSelanjutnya = `\n📅 *Ep ${nomorEp} tayang:* ${tanggal}`;
    }

    // Badge atas: realtime atau biasa
    const badge      = realtime ? '🔴 *REALTIME INFO WIBU*' : '📢 *INFO WIBU*';
    const waktuKirim = new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });

    return (
        `${badge}\n` +
        `${'─'.repeat(28)}\n` +
        `🎌 *${judul}*${judulNative}\n\n` +
        `📖 ${deskripsi}\n\n` +
        `${skor}  |  🎭 ${genre}\n` +
        `🏢 Studio: *${studio}*\n` +
        `📺 Episode: *${eps}*${infoEpSelanjutnya}\n\n` +
        `🔗 ${a.siteUrl || 'https://anilist.co'}\n` +
        `${'─'.repeat(28)}\n` +
        `🕐 _${waktuKirim} WIB_`
    );
}

// ── AMBIL URL GAMBAR COVER / BANNER ──────────────────────────────────────────

function ambilUrlGambar(post) {
    const a = post.anime;
    // Utamakan banner (lebih lebar), lalu cover ukuran besar, lalu medium
    return a.bannerImage || a.coverImage?.extraLarge || a.coverImage?.large || null;
}

// ── SIMULASI / TES KIRIM ──────────────────────────────────────────────────────

// Digunakan oleh perintah `.infowibu test` untuk tes tanpa menunggu jadwal
async function simulasi() {
    const daftar = await ambilAnimeTrending(1, 5);
    if (!daftar.length) throw new Error('Tidak ada data anime dari AniList. Coba lagi nanti.');
    const anime  = daftar[0];
    const post   = { sumber: 'anilist', anime, idUnik: `al-${anime.id}` };
    return {
        caption  : buatCaption(post, { realtime: true }),
        urlGambar: ambilUrlGambar(post),
        judul    : anime.title?.romaji || anime.title?.english || '?',
        idUnik   : post.idUnik,
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
    ambilAnimeTrending,
    ambilAnimeBaru,
    buatCaption,
    ambilUrlGambar,
    simulasi,

    // Alias nama lama supaya tidak error di tempat lain yang sudah pakai
    setGroupEnabled    : aturGrup,
    isGroupEnabled     : cekGrupAktif,
    getEnabledGroups   : daftarGrupAktif,
    getAllGroupSettings : semuaPengaturanGrup,
    markSent           : tandaiSudahKirim,
    alreadySent        : sudahPernahKirim,
    fetchTrendingAnime : ambilAnimeTrending,
    fetchFreshPost     : ambilAnimeBaru,
    formatCaption      : buatCaption,
    getCoverUrl        : ambilUrlGambar,
    simulate           : simulasi,
};
