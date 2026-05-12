'use strict';

/**
 * ─────────────────────────────────────────────────────
 *  FITUR   : Animasu Sub Indo Realtime
 *  Fungsi  : Pantau episode Sub Indo terbaru dari
 *            v1.animasu.app via WP REST API.
 *            Kirim notifikasi ke grup WA saat ada
 *            episode baru yang sudah di-sub Indo.
 *  Sumber  : animasu.app WP REST API + HTML scraping
 * ─────────────────────────────────────────────────────
 */

const axios = require('axios');
const fs    = require('fs');
const path  = require('path');

const FILE_DATA   = path.join(process.cwd(), 'data', 'animasu.json');
const FILE_CONFIG = path.join(process.cwd(), 'config.json');
const BASE_URL    = 'https://v1.animasu.app';
const API_POSTS   = `${BASE_URL}/wp-json/wp/v2/posts`;
const HEADERS     = { 'User-Agent': 'Mozilla/5.0 (compatible; WilyBot/1.0)' };

// ── BACA / SIMPAN ─────────────────────────────────────────────────────────────

function bacaData() {
    try {
        if (fs.existsSync(FILE_DATA)) return JSON.parse(fs.readFileSync(FILE_DATA, 'utf-8'));
    } catch (_) {}
    return { idTerkirim: [] };
}

function simpanData(data) {
    try { fs.writeFileSync(FILE_DATA, JSON.stringify(data, null, 2), 'utf-8'); } catch (_) {}
}

function bacaConfig() {
    try {
        if (fs.existsSync(FILE_CONFIG)) return JSON.parse(fs.readFileSync(FILE_CONFIG, 'utf-8'));
    } catch (_) {}
    return {};
}

function simpanConfig(cfg) {
    try { fs.writeFileSync(FILE_CONFIG, JSON.stringify(cfg, null, 2), 'utf-8'); } catch (_) {}
}

// ── PENGATURAN GRUP ───────────────────────────────────────────────────────────

function getEnabledGroups() {
    const cfg    = bacaConfig();
    const groups = cfg?.animasu?.groups || {};
    return Object.entries(groups)
        .filter(([, v]) => v?.enabled === true)
        .map(([jid]) => jid);
}

function setGroupEnabled(jid, enabled) {
    const cfg = bacaConfig();
    if (!cfg.animasu)        cfg.animasu        = { groups: {} };
    if (!cfg.animasu.groups) cfg.animasu.groups = {};
    cfg.animasu.groups[jid] = { enabled, diubahPada: Date.now() };
    simpanConfig(cfg);
}

// ── HTML HELPER ───────────────────────────────────────────────────────────────

function stripHtml(str) {
    return (str || '')
        .replace(/<[^>]+>/g, ' ')
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#8217;/g, "\u2019")
        .replace(/&#8216;/g, "\u2018")
        .replace(/&#8220;/g, '\u201C')
        .replace(/&#8221;/g, '\u201D')
        .replace(/&#x1F525;/gi, '🔥')
        .replace(/&#x2714;/gi, '✔️')
        .replace(/&#[0-9]+;/g, s => {
            try { return String.fromCodePoint(parseInt(s.slice(2, -1))); } catch (_) { return ''; }
        })
        .replace(/\s+/g, ' ')
        .trim();
}

// ── PARSE HALAMAN DETAIL ANIME ─────────────────────────────────────────────────

function parseDetailPage(html, animeUrl) {
    // Judul utama (strip "Sub Indo" suffix)
    const judulMatch = html.match(/<h1[^>]*itemprop="headline"[^>]*>([\s\S]*?)<\/h1>/i);
    const judul = judulMatch
        ? stripHtml(judulMatch[1]).replace(/\s*Sub\s*Indo\s*$/i, '').trim()
        : '';

    // Judul alternatif
    const alterMatch = html.match(/<span class="alter">([\s\S]*?)<\/span>/i);
    const judulAlt = alterMatch ? stripHtml(alterMatch[1]) : '';

    // Cover image — ambil dari div.thumb (portrait, bukan banner)
    // Konversi WP Jetpack CDN (i{n}.wp.com) ke URL asli untuk kualitas penuh
    const coverMatch = html.match(/<div class="thumb"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"/i);
    const coverRaw   = coverMatch ? coverMatch[1].split('?')[0] : '';
    const cover      = coverRaw.replace(/^https?:\/\/i\d+\.wp\.com\//, 'https://');

    // Info fields dari div.spe
    const speMatch = html.match(/<div class="spe">([\s\S]*?)<\/div>/i);
    const speHtml  = speMatch ? speMatch[1] : '';

    function ambilField(label) {
        const re = new RegExp(`<b>${label}:<\\/b>\\s*([\\s\\S]*?)(?=<\\/span>|<span\\b)`, 'i');
        const m  = speHtml.match(re);
        return m ? stripHtml(m[1]) : '';
    }

    const genre  = ambilField('Genre').replace(/\s*,\s*/g, ', ');
    const status = ambilField('Status').replace(/🔥|✔️|⏳/g, '').trim();
    const rilis  = ambilField('Rilis');
    const jenis  = ambilField('Jenis');
    const durasi = ambilField('Durasi');
    const studio = ambilField('Studio');
    const musim  = ambilField('Musim');

    // Rating site
    const ratingMatch = html.match(/<strong>Rating\s+([0-9.]+)<\/strong>/i);
    const rating = ratingMatch ? ratingMatch[1] : '';

    // Sinopsis
    const sinopsisMatch = html.match(/<span class="desc"[^>]*>([\s\S]*?)<\/span>\s*<\/div>/i);
    const sinopsis = sinopsisMatch
        ? stripHtml(sinopsisMatch[1]).replace(/\s{2,}/g, ' ').trim()
        : '';

    // Episode terbaru (urutan pertama = paling baru)
    const epMatch    = html.match(/<span class="lchx"><a href="([^"]+)">Episode\s+(\d+)<\/a><\/span>/i);
    const latestEpUrl = epMatch ? epMatch[1] : '';
    const latestEpNum = epMatch ? parseInt(epMatch[2]) : 0;

    // Total episode yang sudah tersedia di Animasu (dari daftar episode)
    const allEps = [...html.matchAll(/<span class="lchx"><a href="[^"]+">Episode\s+(\d+)<\/a><\/span>/gi)];
    const totalEp = allEps.length;

    // Total episode seri (dari field "Episode" di .spe, misal "13 Episode")
    const totalSeriRaw = ambilField('Episode');
    const totalSeriMatch = totalSeriRaw.match(/(\d+)/);
    const totalSeri = totalSeriMatch ? parseInt(totalSeriMatch[1]) : 0;

    // Trailer YouTube embed
    const trailerMatch = html.match(/bixbox trailer[\s\S]*?<iframe[^>]+src="https:\/\/www\.youtube\.com\/embed\/([^"?/]+)/i);
    const trailerUrl   = trailerMatch ? `https://www.youtube.com/watch?v=${trailerMatch[1]}` : '';

    return {
        judul, judulAlt, cover, genre, status, rilis, jenis,
        durasi, studio, musim, rating, sinopsis,
        latestEpNum, latestEpUrl, totalEp, totalSeri, trailerUrl,
        url: animeUrl,
    };
}

// ── FETCH ─────────────────────────────────────────────────────────────────────

async function fetchHtml(url) {
    const r = await axios.get(url, { headers: HEADERS, timeout: 15000 });
    return r.data;
}

async function fetchRecentPosts(count = 15) {
    // date_gmt dibutuhkan untuk filter waktu akurat; _embedded ditambah WP otomatis saat _embed dipakai
    const url = `${API_POSTS}?per_page=${count}&_embed=wp%3Aterm&_fields=id,date,date_gmt,slug,title`;
    const r   = await axios.get(url, { headers: HEADERS, timeout: 15000 });
    return r.data;
}

// Dapat anime slug dari post — pakai embedded category (lebih akurat dari slug parsing)
function animeSlugDariPost(post) {
    try {
        const cats = post._embedded?.['wp:term']?.[0] || [];
        if (cats.length > 0 && cats[0].slug) return cats[0].slug;
    } catch (_) {}
    // Fallback: strip "nonton-" prefix dan "-episode-N" suffix
    return (post.slug || '')
        .replace(/^nonton-/, '')
        .replace(/-episode-\d+.*$/, '');
}

function nomorEpisodeDariPost(post) {
    const m = (post.title?.rendered || '').match(/Episode\s+(\d+)/i);
    return m ? parseInt(m[1]) : 0;
}

// ── DEDUP ─────────────────────────────────────────────────────────────────────

function sudahDikirim(id) {
    const data = bacaData();
    return (data.idTerkirim || []).includes(String(id));
}

function tandaiSudahKirim(id) {
    const data = bacaData();
    if (!data.idTerkirim) data.idTerkirim = [];
    data.idTerkirim.unshift(String(id));
    if (data.idTerkirim.length > 300) data.idTerkirim = data.idTerkirim.slice(0, 300);
    simpanData(data);
}

// ── CARI EPISODE BARU ─────────────────────────────────────────────────────────

// menitTerakhir: batas waktu maksimum usia post yang dikirim (default 8 menit — sedikit lebih dari interval 5 menit)
// Post yang lebih lama dari batas ini langsung ditandai "sudah dikirim" tanpa dikirim ke grup,
// sehingga restart bot tidak menyebabkan spam episode lama.
async function cariEpisodeBaru(menitTerakhir = 8) {
    const posts = await fetchRecentPosts(15);
    const batas = Date.now() - menitTerakhir * 60 * 1000;
    const baru  = [];

    for (const post of posts) {
        if (sudahDikirim(post.id)) continue;

        // Gunakan date_gmt (UTC) agar perbandingan waktu akurat
        const waktuPost = post.date_gmt
            ? new Date(post.date_gmt + 'Z').getTime()
            : new Date(post.date).getTime() - 7 * 3600 * 1000; // fallback kurangi UTC+7

        if (waktuPost < batas) {
            // Post terlalu lama — tandai sudah dikirim tapi JANGAN kirim ke grup
            tandaiSudahKirim(post.id);
            continue;
        }

        const animeSlug = animeSlugDariPost(post);
        const epNum     = nomorEpisodeDariPost(post);
        if (!animeSlug) continue;

        try {
            const animeUrl = `${BASE_URL}/anime/${animeSlug}/`;
            const html     = await fetchHtml(animeUrl);
            const detail   = parseDetailPage(html, animeUrl);
            baru.push({ postId: post.id, postDate: post.date, epNum, animeSlug, ...detail });
        } catch (e) {
            console.warn(`[Animasu] Gagal fetch detail "${animeSlug}":`, e?.message);
        }
    }

    return baru;
}

// ── SIMULASI (TEST) ───────────────────────────────────────────────────────────

async function simulasi() {
    const posts = await fetchRecentPosts(1);
    if (!posts.length) throw new Error('Tidak ada post terbaru dari Animasu');

    const post      = posts[0];
    const animeSlug = animeSlugDariPost(post);
    const epNum     = nomorEpisodeDariPost(post);
    const animeUrl  = `${BASE_URL}/anime/${animeSlug}/`;
    const html      = await fetchHtml(animeUrl);
    const detail    = parseDetailPage(html, animeUrl);
    const data      = { postId: post.id, postDate: post.date, epNum, animeSlug, ...detail };
    const caption   = buatCaption(data);
    return { caption, urlGambar: data.cover || null };
}

// ── FORMAT CAPTION ────────────────────────────────────────────────────────────

const SEP  = '━━━━━━━━━━━━━━━━━━';
const SEP2 = '┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄';

function buatBarisInfo(items) {
    const valid = items.filter(([, val]) => val !== null && val !== undefined && val !== '' && val !== '-');
    return valid.map(([label, val], i) => {
        const prefix = i === valid.length - 1 ? '╰' : '├';
        return `${prefix} ${label} : ${val}`;
    }).join('\n');
}

function potongSinopsis(teks, maks = 350) {
    if (!teks || teks.length <= maks) return teks || '-';
    const potong   = teks.slice(0, maks);
    const lastSpace = potong.lastIndexOf(' ');
    return (lastSpace > 0 ? potong.slice(0, lastSpace) : potong) + '...';
}

function buatCaption(data) {
    const {
        judul, judulAlt, epNum, latestEpNum, latestEpUrl, totalEp, totalSeri,
        genre, status, rilis, jenis, durasi, studio, musim, rating,
        sinopsis, trailerUrl, url,
    } = data;

    const ep  = epNum || latestEpNum || '?';
    const sinopsisBlock = potongSinopsis(sinopsis).split('\n').map(b => `> ${b}`).join('\n');
    const waktuKirim    = new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });

    const sedangTayang = (status || '').toLowerCase().includes('tayang') &&
                         !(status || '').toLowerCase().includes('selesai');

    // Header episode: "Ep 7/13" kalau total seri diketahui, kalau tidak "Ep 7"
    const epHeader = totalSeri ? `${ep}/${totalSeri}` : String(ep);

    // Baris info episode:
    // - Kalau total seri ada: "7/13  (7 tersedia)"   atau  "13/13" kalau selesai
    // - Kalau hanya totalEp:  "7 ep tersedia"        atau  "7 ep" kalau selesai
    let epInfo = null;
    if (totalSeri) {
        epInfo = sedangTayang
            ? `${ep}/${totalSeri}  _(${totalEp} tersedia)_`
            : `${ep}/${totalSeri}`;
    } else if (totalEp) {
        epInfo = sedangTayang ? `${totalEp} ep tersedia` : `${totalEp} ep`;
    }

    const seksi1 = buatBarisInfo([
        ['🗂️ *Jenis*   ', jenis  || null],
        ['⏱️ *Durasi*  ', durasi || null],
        ['📦 *Episode* ', epInfo],
        ['🗓️ *Rilis*   ', rilis  || null],
        ['🌸 *Musim*   ', musim  || null],
        ['📡 *Status*  ', status || null],
        ['🏢 *Studio*  ', studio || null],
    ]);

    const seksi2 = buatBarisInfo([
        ['⭐ *Rating*  ', rating ? `${rating}/10` : null],
        ['🎭 *Genre*   ', genre  ? `_${genre}_`  : null],
    ]);

    return (
        `🟢 *SUB INDO SUDAH TAYANG!*\n` +
        `${SEP}\n\n` +
        `🎌 *${judul}*\n` +
        `${judulAlt ? `_${judulAlt}_\n` : ''}` +
        `\n📺 *Episode ${epHeader}*\n` +
        `\n📖 *Sinopsis*\n` +
        `${sinopsisBlock}\n\n` +
        `${SEP}\n` +
        `📋 *Info Anime*\n` +
        `${SEP2}\n` +
        `${seksi1}\n` +
        `${SEP2}\n` +
        `${seksi2}\n` +
        `${SEP}\n` +
        `${trailerUrl ? `🎬 *PV*     : ${trailerUrl}\n` : ''}` +
        `▶️ *Tonton*  : ${latestEpUrl || url}\n` +
        `🔗 *Anime*   : ${url}\n` +
        `🕐 _${waktuKirim} WIB_`
    );
}

function ambilUrlGambar(data) {
    return data?.cover || null;
}

// ── STATUS: DAFTAR ANIME SEDANG TAYANG + SISA EPISODE ────────────────────────

async function getAiringStatus(jumlahPost = 40) {
    const posts = await fetchRecentPosts(jumlahPost);

    // Kelompokkan post per anime slug — ambil nomor episode terbesar per slug
    const map = new Map();
    for (const post of posts) {
        const slug  = animeSlugDariPost(post);
        const epNum = nomorEpisodeDariPost(post);
        if (!slug) continue;
        if (!map.has(slug) || epNum > map.get(slug).epNum) {
            map.set(slug, { slug, epNum, postDate: post.date });
        }
    }

    const slugList = [...map.values()];

    // Fetch detail per anime secara paralel (max 6 sekaligus untuk hindari rate-limit)
    const BATCH = 6;
    const results = [];
    for (let i = 0; i < slugList.length; i += BATCH) {
        const chunk = slugList.slice(i, i + BATCH);
        const settled = await Promise.allSettled(
            chunk.map(async ({ slug, epNum, postDate }) => {
                const animeUrl = `${BASE_URL}/anime/${slug}/`;
                const html     = await fetchHtml(animeUrl);
                const detail   = parseDetailPage(html, animeUrl);
                const sisaEp   = (detail.totalSeri && epNum)
                    ? Math.max(0, detail.totalSeri - epNum)
                    : null;
                return {
                    judul     : detail.judul || slug,
                    musim     : detail.musim || '-',
                    status    : detail.status || '-',
                    epTerbaru : epNum || detail.latestEpNum || 0,
                    totalSeri : detail.totalSeri || 0,
                    sisaEp,
                    url       : animeUrl,
                    postDate,
                };
            })
        );
        for (const s of settled) {
            if (s.status === 'fulfilled') results.push(s.value);
        }
        if (i + BATCH < slugList.length) await new Promise(r => setTimeout(r, 500));
    }

    // Sort: paling banyak sisa di atas; yang tidak diketahui (null) di bawah
    results.sort((a, b) => {
        if (a.sisaEp === null && b.sisaEp === null) return 0;
        if (a.sisaEp === null) return 1;
        if (b.sisaEp === null) return -1;
        return b.sisaEp - a.sisaEp;
    });

    return results;
}

// ── EXPORT ────────────────────────────────────────────────────────────────────

module.exports = {
    getEnabledGroups,
    setGroupEnabled,
    cariEpisodeBaru,
    buatCaption,
    ambilUrlGambar,
    tandaiSudahKirim,
    simulasi,
    getAiringStatus,
};
