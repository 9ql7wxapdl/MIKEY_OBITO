'use strict';

/**
 * ─────────────────────────────────────────────────────
 *  FITUR   : TVOne News Realtime
 *  Fungsi  : Pantau berita terbaru dari tvonenews.com
 *            setiap 5 menit. Kirim notifikasi ke grup
 *            WA saat ada berita baru.
 *  Sumber  : tvonenews.com (scraping HTML)
 * ─────────────────────────────────────────────────────
 */

const axios = require('axios');
const fs    = require('fs');
const path  = require('path');

const FILE_DATA   = path.join(process.cwd(), 'data', 'tvonenews', 'state.json');
const FILE_LOG    = path.join(process.cwd(), 'data', 'tvonenews', 'log.json');
fs.mkdirSync(path.join(process.cwd(), 'data', 'tvonenews'), { recursive: true });
const FILE_CONFIG = path.join(process.cwd(), 'config.json');
const BASE_URL    = 'https://www.tvonenews.com';
const HEADERS     = {
    'User-Agent'     : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept'         : 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7',
};

// Max ID yang disimpan di list dedup
const MAX_SEEN = 500;

// ── BACA / SIMPAN DATA ────────────────────────────────────────────────────────

function bacaData() {
    try {
        if (fs.existsSync(FILE_DATA)) return JSON.parse(fs.readFileSync(FILE_DATA, 'utf-8'));
    } catch (_) {}
    return { idTerkirim: [], lastCheckTime: null };
}

function simpanData(data) {
    try { fs.writeFileSync(FILE_DATA, JSON.stringify(data, null, 2), 'utf-8'); } catch (_) {}
}

function bacaLog() {
    try {
        if (fs.existsSync(FILE_LOG)) return JSON.parse(fs.readFileSync(FILE_LOG, 'utf-8'));
    } catch (_) {}
    return { terkirim: [] };
}

function simpanLog(log) {
    try { fs.writeFileSync(FILE_LOG, JSON.stringify(log, null, 2), 'utf-8'); } catch (_) {}
}

// ── CONFIG / GRUP ─────────────────────────────────────────────────────────────

function bacaConfig() {
    try {
        if (fs.existsSync(FILE_CONFIG)) return JSON.parse(fs.readFileSync(FILE_CONFIG, 'utf-8'));
    } catch (_) {}
    return {};
}

function simpanConfig(cfg) {
    try { fs.writeFileSync(FILE_CONFIG, JSON.stringify(cfg, null, 2), 'utf-8'); } catch (_) {}
}

function setGroupEnabled(jidGrup, aktif) {
    const cfg = bacaConfig();
    if (!cfg.tvonenews)        cfg.tvonenews        = { groups: {} };
    if (!cfg.tvonenews.groups) cfg.tvonenews.groups = {};
    cfg.tvonenews.groups[jidGrup] = { enabled: aktif, diubahPada: Date.now() };
    simpanConfig(cfg);
}

function getEnabledGroups() {
    const cfg    = bacaConfig();
    const groups = cfg.tvonenews?.groups || {};
    return Object.entries(groups)
        .filter(([, v]) => v.enabled === true)
        .map(([jid]) => jid);
}

// ── HELPER ────────────────────────────────────────────────────────────────────

function stripHtml(teks) {
    return (teks || '')
        .replace(/<[^>]+>/g, ' ')
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#039;/g, "'")
        .replace(/&nbsp;/g, ' ')
        .replace(/&#(\d+);/g, (_, n) => {
            try { return String.fromCodePoint(parseInt(n)); } catch (_) { return ''; }
        })
        .replace(/\s{2,}/g, ' ')
        .trim();
}

function idDariUrl(url) {
    const m = url.match(/\/(\d{4,8})-/);
    return m ? m[1] : null;
}

function kategoriDariUrl(url) {
    const bagian = url.replace(BASE_URL, '').split('/').filter(Boolean);
    // /berita/nasional/439944-xxx  → "Berita › Nasional"
    // /ekonomi/439946-xxx          → "Ekonomi"
    const bersih = bagian.filter(b => !/^\d/.test(b));
    return bersih.map(b => b.charAt(0).toUpperCase() + b.slice(1)).join(' › ');
}

// Hapus suffix ukuran thumbnail → gambar original
// contoh: _375_211.jpg → .jpg ; _488_274.jpg → .jpg
function gambarHD(thumbUrl) {
    if (!thumbUrl) return null;
    return thumbUrl.replace(/_\d+_\d+(\.[a-z]+)$/i, '$1');
}

// ── FETCH DENGAN RETRY ────────────────────────────────────────────────────────

async function fetchDenganRetry(fn, maxRetry = 3, delayMs = 3000) {
    let lastErr;
    for (let i = 0; i < maxRetry; i++) {
        try { return await fn(); }
        catch (e) {
            lastErr = e;
            if (i < maxRetry - 1) await new Promise(r => setTimeout(r, delayMs));
        }
    }
    throw lastErr;
}

async function fetchHtml(url) {
    return fetchDenganRetry(async () => {
        const r = await axios.get(url, { headers: HEADERS, timeout: 20000 });
        return r.data;
    });
}

// ── PARSE DAFTAR ARTIKEL DARI HOMEPAGE ───────────────────────────────────────

function parseArtikelList(html) {
    const artikel = [];
    const seen    = new Set();

    // Cari blok article-list-row
    const rowRe = /class="article-list-row"([\s\S]{80,3000}?)(?=class="article-list-row"|class="btn btn-more|<\/section>|<\/div>\s*<\/div>\s*<\/section>|$)/g;
    let m;
    while ((m = rowRe.exec(html)) !== null) {
        const blok = m[1];

        // URL artikel (harus ada ID angka)
        const urlM = blok.match(/href="(https:\/\/www\.tvonenews\.com\/[^"]+\/\d{4,8}-[^"]+)"/);
        if (!urlM) continue;
        const url   = urlM[1].split('"')[0];
        const artId = idDariUrl(url);
        if (!artId || seen.has(artId)) continue;
        seen.add(artId);

        // Judul dari <h2>
        const h2M = blok.match(/<h2[^>]*>([\s\S]*?)<\/h2>/);
        if (!h2M) continue;
        const judul = stripHtml(h2M[1]);
        if (!judul) continue;

        // Thumbnail (lazy-loaded pakai data-original)
        const imgM  = blok.match(/data-original="(https:\/\/thumbs\.tvonenews\.com\/[^"]+)"/);
        const thumb = imgM ? imgM[1] : null;

        // Kategori
        const catM     = blok.match(/class="ali-cate[^"]*"[^>]*>([\s\S]{0,150})/);
        const kategori = catM ? stripHtml(catM[1]) : kategoriDariUrl(url);

        artikel.push({ artId, url, judul, thumb, kategori });
    }
    return artikel;
}

// ── PARSE DETAIL ARTIKEL ──────────────────────────────────────────────────────

function parseDetailArtikel(html, url) {
    // Judul H1
    const judulM = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
    const judul  = judulM ? stripHtml(judulM[1]) : '';

    // Tanggal terbit: "Rabu, 13 Mei 2026 - 07:26 WIB"
    const dateM   = html.match(/class="detail-date"[^>]*>\s*([\s\S]{5,80}?)\s*</);
    const tanggal = dateM ? stripHtml(dateM[1]) : '';

    // OG image → kualitas terbaik yang disediakan web
    const ogM     = html.match(/property="og:image"[^>]+content="([^"]+)"/);
    const rawCover = ogM ? ogM[1] : null;

    // Fallback: gambar pertama di detail-media
    const mediaM     = html.match(/class="detail-(?:media|img)[^"]*"[\s\S]{0,800}?(?:src|data-original)="(https?:\/\/thumbs\.tvonenews\.com\/[^"]+)"/);
    const rawFallback = mediaM ? mediaM[1] : null;

    // Ambil cover HD (hapus suffix ukuran dari thumbnail)
    const cover = gambarHD(rawCover) || gambarHD(rawFallback) || rawCover || rawFallback;

    // Penulis / reporter — ada di class="detail-author-link"
    const authorLinkM = html.match(/class="detail-author-link"[^>]*>\s*([\s\S]{2,80}?)\s*<\/div>/);
    const penulis     = authorLinkM ? stripHtml(authorLinkM[1]) : '';

    // Kategori dari breadcrumb
    const bcLinks = [...html.matchAll(/class="breadcrumb-step"[^>]+href="https:\/\/www\.tvonenews\.com\/([^"/]+)(?:\/([^"/]+))?[^"]*"[^>]*>([^<]+)<\/a>/g)];
    let kategori = '';
    if (bcLinks.length >= 2) {
        const parts = bcLinks.slice(1).map(x => stripHtml(x[3])).filter(Boolean);
        kategori = parts.join(' › ');
    }
    if (!kategori) kategori = kategoriDariUrl(url);

    // Konten artikel — strip iklan & noise
    const kontenM = html.match(/class="detail-content"[^>]*>([\s\S]{0,12000})/);
    let ringkasan = '';
    if (kontenM) {
        const raw = kontenM[1]
            .replace(/<script[\s\S]*?<\/script>/gi, '')
            .replace(/<style[\s\S]*?<\/style>/gi, '')
            .replace(/ADVERTISEMENT\s*/gi, '')
            .replace(/GULIR UNTUK LANJUT BACA\s*/gi, '')
            .replace(/<div[^>]*(?:iklan|ads|advert)[^>]*>[\s\S]*?<\/div>/gi, '');
        const teks = stripHtml(raw).replace(/\s{2,}/g, ' ').trim();
        // Ambil 400 karakter pertama sebagai ringkasan
        ringkasan = teks.length > 400 ? teks.slice(0, 400).trimEnd() + '...' : teks;
    }

    // Fallback: meta description
    if (!ringkasan) {
        const descM = html.match(/name="description"[^>]+content="([^"]{10,400})"/);
        ringkasan = descM ? descM[1] : '';
    }

    return { judul, tanggal, cover, penulis, kategori, ringkasan, url };
}

// ── DEDUP ─────────────────────────────────────────────────────────────────────

function sudahDikirim(id) {
    return (bacaData().idTerkirim || []).includes(String(id));
}

function tandaiSudahKirim(id) {
    const data = bacaData();
    if (!data.idTerkirim) data.idTerkirim = [];
    if (!data.idTerkirim.includes(String(id))) {
        data.idTerkirim.unshift(String(id));
        if (data.idTerkirim.length > MAX_SEEN) data.idTerkirim = data.idTerkirim.slice(0, MAX_SEEN);
        simpanData(data);
    }
}

function tandaiDanLog(item, grupList) {
    tandaiSudahKirim(item.artId);
    try {
        const log = bacaLog();
        if (!Array.isArray(log.terkirim)) log.terkirim = [];
        if (!log.terkirim.some(e => String(e.artId) === String(item.artId))) {
            log.terkirim.unshift({
                artId     : String(item.artId),
                judul     : item.judul || '-',
                kategori  : item.kategori || '',
                tanggal   : item.tanggal || null,
                penulis   : item.penulis || '',
                waktuKirim: new Date().toISOString(),
                grupCount : grupList.length,
                grupList,
                cover     : item.cover || null,
                url       : item.url,
            });
            if (log.terkirim.length > 300) log.terkirim = log.terkirim.slice(0, 300);
            simpanLog(log);
        }
    } catch (e) {
        console.warn('[TVOneNews] Gagal simpan log:', e?.message);
    }
}

function getRecentLog(jumlah = 20) {
    return (bacaLog().terkirim || []).slice(0, jumlah);
}

// ── CARI BERITA BARU (REALTIME) ───────────────────────────────────────────────

async function cariBeritaBaru() {
    const now  = Date.now();
    const data = bacaData();

    // Pertama kali run → tandai semua yang ada, TIDAK kirim (hindari spam)
    const isFirstRun = !data.lastCheckTime;
    data.lastCheckTime = now;
    if (!data.idTerkirim) data.idTerkirim = [];
    simpanData(data);

    let htmlHome = '';
    try {
        htmlHome = await fetchHtml(BASE_URL);
    } catch (e) {
        console.error('[TVOneNews] ❌ Gagal fetch homepage:', e?.message);
        return [];
    }

    const artikelList = parseArtikelList(htmlHome);

    if (isFirstRun) {
        for (const art of artikelList) tandaiSudahKirim(art.artId);
        console.log(`[TVOneNews] 🆕 First run — tandai ${artikelList.length} artikel sebagai sudah dilihat`);
        return [];
    }

    const baru = [];
    for (const art of artikelList) {
        if (sudahDikirim(art.artId)) continue;

        try {
            const htmlDetail = await fetchHtml(art.url);
            const detail     = parseDetailArtikel(htmlDetail, art.url);
            baru.push({
                ...art,
                ...detail,
                // Detail override, tapi cover dari detail lebih baik
                cover: detail.cover || gambarHD(art.thumb) || art.thumb,
            });
        } catch (e) {
            console.warn(`[TVOneNews] ❌ Detail gagal (${art.artId}):`, e?.message);
            // Pakai data list saja
            baru.push({
                ...art,
                cover    : gambarHD(art.thumb) || art.thumb,
                tanggal  : '',
                penulis  : '',
                ringkasan: '',
            });
        }
        await new Promise(r => setTimeout(r, 1200));
    }

    return baru;
}

// ── DOWNLOAD GAMBAR SEBAGAI BUFFER ────────────────────────────────────────────

async function downloadImageBuffer(url) {
    if (!url) return null;
    try {
        const r = await axios.get(url, {
            headers     : { ...HEADERS, Accept: 'image/*' },
            responseType: 'arraybuffer',
            timeout     : 20000,
        });
        return Buffer.from(r.data);
    } catch (e) {
        console.warn('[TVOneNews] ⚠️ Gagal download gambar:', e?.message);
        return null;
    }
}

// ── FORMAT CAPTION ────────────────────────────────────────────────────────────

const SEP  = '━━━━━━━━━━━━━━━━━━';
const SEP2 = '┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄';

function buatCaption(item) {
    const { judul, kategori, tanggal, penulis, ringkasan, url } = item;

    const sekarang    = new Date();
    const opsiHari    = { timeZone: 'Asia/Jakarta', weekday: 'long' };
    const opsiTgl     = { timeZone: 'Asia/Jakarta', day: '2-digit', month: 'long', year: 'numeric' };
    const opsiJam     = { timeZone: 'Asia/Jakarta', hour: '2-digit', minute: '2-digit', hour12: false };
    const namaHari    = sekarang.toLocaleDateString('id-ID', opsiHari);
    const tglLengkap  = sekarang.toLocaleDateString('id-ID', opsiTgl);
    const jamMenit    = sekarang.toLocaleTimeString('id-ID', opsiJam).replace('.', ':');
    const headerWaktu = `${namaHari}, ${tglLengkap} · ${jamMenit} WIB`;

    const infoRows = [];
    if (kategori) infoRows.push(`├ 🗂️ *Rubrik*  : ${kategori}`);
    if (tanggal)  infoRows.push(`├ 📅 *Terbit*  : ${tanggal}`);
    if (penulis)  infoRows.push(`╰ ✍️ *Penulis* : ${penulis}`);

    const ringkasanBlock = ringkasan
        ? ringkasan.split('\n').map(l => `> ${l.trim()}`).filter(l => l !== '>').join('\n')
        : '';

    return (
        `📰 *BERITA TERBARU — TVONE NEWS*\n` +
        `${SEP}\n` +
        `📅 _${headerWaktu}_\n` +
        `${SEP}\n\n` +
        `*${judul}*\n\n` +
        (ringkasanBlock ? `📖 *Ringkasan*\n${ringkasanBlock}\n\n` : '') +
        `${SEP}\n` +
        `📋 *Info Berita*\n` +
        `${SEP2}\n` +
        (infoRows.length ? infoRows.join('\n') + '\n' : '') +
        `${SEP}\n` +
        `🔗 *Baca Selengkapnya*\n` +
        `${url}`
    );
}

// ── SIMULASI (TEST) ───────────────────────────────────────────────────────────

async function simulasi() {
    const html        = await fetchHtml(BASE_URL);
    const artikelList = parseArtikelList(html);
    if (!artikelList.length) throw new Error('Tidak ada artikel dari TVOne News');

    // Ambil artikel pertama (terbaru)
    const art        = artikelList[0];
    const htmlDetail = await fetchHtml(art.url);
    const detail     = parseDetailArtikel(htmlDetail, art.url);

    const item = {
        ...art,
        ...detail,
        cover: detail.cover || gambarHD(art.thumb) || art.thumb,
    };

    const caption   = buatCaption(item);
    const urlGambar = item.cover || null;
    const imgBuffer = await downloadImageBuffer(urlGambar);
    return { caption, urlGambar, imgBuffer, item };
}

// ── EXPORT ────────────────────────────────────────────────────────────────────

module.exports = {
    getEnabledGroups,
    setGroupEnabled,
    cariBeritaBaru,
    buatCaption,
    downloadImageBuffer,
    tandaiSudahKirim,
    tandaiDanLog,
    getRecentLog,
    simulasi,
};
