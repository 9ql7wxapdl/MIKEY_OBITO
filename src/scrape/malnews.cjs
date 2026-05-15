'use strict';

/**
 * ─────────────────────────────────────────────────────
 *  FITUR   : MyAnimeList News Realtime
 *  Fungsi  : Pantau berita anime terbaru dari
 *            myanimelist.net/news via RSS feed.
 *            Judul & ringkasan diterjemahkan ke
 *            Bahasa Indonesia otomatis.
 *  Sumber  : myanimelist.net RSS + Google Translate
 * ─────────────────────────────────────────────────────
 */

const axios  = require('axios');
const fs     = require('fs');
const path   = require('path');

const FILE_DATA   = path.join(process.cwd(), 'data', 'malnews', 'state.json');
const FILE_LOG    = path.join(process.cwd(), 'data', 'malnews', 'log.json');
const FILE_CONFIG = path.join(process.cwd(), 'config.json');
fs.mkdirSync(path.join(process.cwd(), 'data', 'malnews'), { recursive: true });

const RSS_URL = 'https://myanimelist.net/rss/news.xml';
const MAX_SEEN     = 300;
const RETRY_TTL_MS = 30 * 60 * 1000; // 30 menit

const HEADERS = {
    'User-Agent'     : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept'         : 'application/rss+xml, application/xml, text/xml, */*',
    'Accept-Language': 'en-US,en;q=0.9',
};

// ── BACA / SIMPAN DATA ────────────────────────────────────────────────────────

function bacaData() {
    try {
        if (fs.existsSync(FILE_DATA)) return JSON.parse(fs.readFileSync(FILE_DATA, 'utf-8'));
    } catch (_) {}
    return { idTerkirim: [], idGagal: [], lastCheckTime: null };
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

function bacaConfig() {
    try {
        if (fs.existsSync(FILE_CONFIG)) return JSON.parse(fs.readFileSync(FILE_CONFIG, 'utf-8'));
    } catch (_) {}
    return {};
}

function simpanConfig(cfg) {
    try { fs.writeFileSync(FILE_CONFIG, JSON.stringify(cfg, null, 2), 'utf-8'); } catch (_) {}
}

// ── CONFIG / GRUP ─────────────────────────────────────────────────────────────

function getEnabledGroups() {
    const cfg    = bacaConfig();
    const groups = cfg?.malnews?.groups || {};
    return Object.entries(groups)
        .filter(([, v]) => v?.enabled === true)
        .map(([jid]) => jid);
}

function setGroupEnabled(jid, enabled) {
    const cfg = bacaConfig();
    if (!cfg.malnews)        cfg.malnews        = { groups: {} };
    if (!cfg.malnews.groups) cfg.malnews.groups = {};
    cfg.malnews.groups[jid] = { enabled, diubahPada: Date.now() };
    simpanConfig(cfg);
}

// ── HELPER ────────────────────────────────────────────────────────────────────

function stripHtml(teks) {
    return (teks || '')
        .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
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
    const m = (url || '').match(/myanimelist\.net\/news\/(\d+)/);
    return m ? m[1] : null;
}

function ambilCdata(tag) {
    const m = tag.match(/<!\[CDATA\[([\s\S]*?)\]\]>/);
    return m ? m[1].trim() : stripHtml(tag);
}

// ── PARSE RSS ─────────────────────────────────────────────────────────────────

function parseRSS(xml) {
    const items = [];
    const itemRe = /<item>([\s\S]*?)<\/item>/g;
    let m;
    while ((m = itemRe.exec(xml)) !== null) {
        const blok = m[1];

        const titleM = blok.match(/<title>([\s\S]*?)<\/title>/);
        const linkM  = blok.match(/<link>([\s\S]*?)<\/link>/) ||
                       blok.match(/<guid[^>]*>([\s\S]*?)<\/guid>/);
        const descM  = blok.match(/<description>([\s\S]*?)<\/description>/);
        const dateM  = blok.match(/<pubDate>([\s\S]*?)<\/pubDate>/);
        const encM   = blok.match(/<media:thumbnail[^>]*url="([^"]+)"/) ||
                       blok.match(/<media:thumbnail[^>]*>(https?:\/\/[^<]+)<\/media:thumbnail>/) ||
                       blok.match(/<enclosure[^>]+url="([^"]+)"/);

        const url   = linkM ? stripHtml(linkM[1]).trim() : '';
        const artId = idDariUrl(url);
        if (!artId || !url) continue;

        const judul    = titleM   ? stripHtml(ambilCdata(titleM[1])) : '';
        const deskripsi = descM   ? stripHtml(ambilCdata(descM[1]))  : '';
        const pubDate  = dateM    ? dateM[1].trim()                  : '';
        const gambar   = encM     ? encM[1]                          : null;

        items.push({ artId, url, judul, deskripsi, pubDate, gambar });
    }
    return items;
}

// ── TERJEMAHAN BAHASA INDONESIA ───────────────────────────────────────────────

async function terjemahkan(teks) {
    if (!teks || !teks.trim()) return teks;
    try {
        const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=id&dt=t&q=${encodeURIComponent(teks)}`;
        const res = await axios.get(url, {
            headers: { 'User-Agent': 'Mozilla/5.0' },
            timeout: 10000,
        });
        const data = res.data;
        if (!Array.isArray(data) || !Array.isArray(data[0])) return teks;
        return data[0]
            .filter(chunk => Array.isArray(chunk) && chunk[0])
            .map(chunk => chunk[0])
            .join('')
            .trim() || teks;
    } catch (_) {
        return teks; // fallback ke teks asli
    }
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

async function fetchRSS() {
    return fetchDenganRetry(async () => {
        const r = await axios.get(RSS_URL, { headers: HEADERS, timeout: 20000 });
        return r.data;
    });
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
                judul     : item.judulID || item.judul || '-',
                waktuKirim: new Date().toISOString(),
                grupCount : grupList.length,
                grupList,
                gambar    : item.gambar || null,
                url       : item.url,
            });
            if (log.terkirim.length > 300) log.terkirim = log.terkirim.slice(0, 300);
            simpanLog(log);
        }
    } catch (e) {
        console.warn('[MALNews] Gagal simpan log:', e?.message);
    }
}

function getRecentLog(jumlah = 20) {
    return (bacaLog().terkirim || []).slice(0, jumlah);
}

// ── ENRICH: TERJEMAHKAN ITEM ──────────────────────────────────────────────────

async function enrichItem(item) {
    const [judulID, deskripsiID] = await Promise.all([
        terjemahkan(item.judul),
        terjemahkan(item.deskripsi),
    ]);
    return { ...item, judulID, deskripsiID };
}

// ── CARI BERITA BARU (REALTIME) ───────────────────────────────────────────────

async function cariBeritaBaru() {
    const now  = Date.now();
    const data = bacaData();

    const isFirstRun = !data.lastCheckTime;

    // Simpan waktu check SEBELUM proses — sama seperti animasu
    data.lastCheckTime = now;
    if (!data.idTerkirim) data.idTerkirim = [];
    if (!data.idGagal)    data.idGagal    = [];
    simpanData(data);

    const baru        = [];
    const idGagalBaru = [];

    // ── Retry gagal sebelumnya ─────────────────────────────────────────────────
    for (const gagal of (data.idGagal || [])) {
        if (sudahDikirim(gagal.artId)) continue;
        const usiaGagal = now - new Date(gagal.pertamaGagal).getTime();
        if (usiaGagal > RETRY_TTL_MS) {
            console.log(`[MALNews] ⏭️ Retry timeout: "${gagal.judul}" diabaikan`);
            tandaiSudahKirim(gagal.artId);
            continue;
        }
        try {
            const enriched = await enrichItem(gagal);
            console.log(`[MALNews] 🔄 Retry berhasil: "${gagal.judul}"`);
            baru.push(enriched);
        } catch (e) {
            console.warn(`[MALNews] 🔄 Retry masih gagal "${gagal.judul}":`, e?.message);
            idGagalBaru.push(gagal);
        }
    }

    // ── Fetch RSS ──────────────────────────────────────────────────────────────
    let items = [];
    try {
        const xml = await fetchRSS();
        items = parseRSS(xml);
    } catch (e) {
        console.error('[MALNews] ❌ Gagal fetch RSS:', e?.message);
        return baru;
    }

    // ── Pertama kali bot jalan — tandai semua sebagai seen, jangan kirim ───────
    if (isFirstRun) {
        console.log(`[MALNews] 🚀 First run — tandai ${items.length} berita sebagai seen`);
        const df = bacaData();
        for (const item of items) {
            if (!df.idTerkirim.includes(String(item.artId))) {
                df.idTerkirim.unshift(String(item.artId));
            }
        }
        df.idGagal = idGagalBaru;
        simpanData(df);
        return [];
    }

    // ── Run normal ─────────────────────────────────────────────────────────────
    for (const item of items) {
        if (sudahDikirim(item.artId)) continue;
        try {
            const enriched = await enrichItem(item);
            baru.push(enriched);
        } catch (e) {
            console.warn(`[MALNews] ❌ Gagal terjemah "${item.judul}":`, e?.message);
            idGagalBaru.push({
                ...item,
                pertamaGagal: new Date().toISOString(),
            });
        }
    }

    const dataFinal = bacaData();
    dataFinal.idGagal = idGagalBaru;
    simpanData(dataFinal);

    return baru;
}

// ── FORMAT CAPTION ────────────────────────────────────────────────────────────

const SEP  = '━━━━━━━━━━━━━━━━━━';
const SEP2 = '┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄';

function formatTanggal(pubDate) {
    try {
        const d = new Date(pubDate);
        return d.toLocaleString('id-ID', {
            timeZone: 'Asia/Jakarta',
            weekday : 'long',
            day     : '2-digit',
            month   : 'long',
            year    : 'numeric',
            hour    : '2-digit',
            minute  : '2-digit',
            hour12  : false,
        }).replace('.', ':') + ' WIB';
    } catch (_) {
        return pubDate || '-';
    }
}

function buatCaption(item) {
    const { judulID, judul, deskripsiID, deskripsi, pubDate, url } = item;

    const sekarang    = new Date();
    const opsiHari    = { timeZone: 'Asia/Jakarta', weekday: 'long' };
    const opsiTgl     = { timeZone: 'Asia/Jakarta', day: '2-digit', month: 'long', year: 'numeric' };
    const opsiJam     = { timeZone: 'Asia/Jakarta', hour: '2-digit', minute: '2-digit', hour12: false };
    const namaHari    = sekarang.toLocaleDateString('id-ID', opsiHari);
    const tglLengkap  = sekarang.toLocaleDateString('id-ID', opsiTgl);
    const jamMenit    = sekarang.toLocaleTimeString('id-ID', opsiJam).replace('.', ':');
    const headerWaktu = `${namaHari}, ${tglLengkap} · ${jamMenit} WIB`;

    const judulTampil = judulID || judul || '-';
    const isiTampil   = deskripsiID || deskripsi || '';
    const tglTampil   = pubDate ? formatTanggal(pubDate) : '-';

    const isiBlock = isiTampil
        ? isiTampil.split('\n').map(l => `> ${l.trim()}`).filter(l => l !== '>').join('\n')
        : '';

    return (
        `📰 *BERITA TERBARU — MYANIMELIST*\n` +
        `${SEP}\n` +
        `📅 _${headerWaktu}_\n` +
        `${SEP}\n\n` +
        `*${judulTampil}*\n\n` +
        (isiBlock ? `📖 *Ringkasan*\n${isiBlock}\n\n` : '') +
        `${SEP}\n` +
        `📋 *Info Berita*\n` +
        `${SEP2}\n` +
        `├ 🗂️ *Sumber*  : MyAnimeList News\n` +
        `╰ 📅 *Terbit*  : ${tglTampil}\n` +
        `${SEP}\n` +
        `🔗 *Baca Selengkapnya*\n` +
        `${url}`
    );
}

function ambilUrlGambar(item) {
    return item?.gambar || null;
}

// ── SIMULASI (TEST) ───────────────────────────────────────────────────────────

async function simulasi() {
    console.log('[MALNews] 🔄 Fetch RSS...');
    const xml   = await fetchRSS();
    const items = parseRSS(xml);
    if (!items.length) throw new Error('Tidak ada berita dari MyAnimeList RSS');

    const item = items[0];
    console.log(`[MALNews] 📰 Judul asli: "${item.judul}"`);
    console.log(`[MALNews] 🌐 Menerjemahkan ke Bahasa Indonesia...`);

    const enriched = await enrichItem(item);
    console.log(`[MALNews] ✅ Judul ID: "${enriched.judulID}"`);
    console.log(`[MALNews] ✅ Deskripsi ID: "${enriched.deskripsiID?.slice(0, 100)}..."`);

    const caption   = buatCaption(enriched);
    const urlGambar = ambilUrlGambar(enriched);
    return { caption, urlGambar, item: enriched };
}

// ── EXPORT ────────────────────────────────────────────────────────────────────

module.exports = {
    getEnabledGroups,
    setGroupEnabled,
    cariBeritaBaru,
    buatCaption,
    ambilUrlGambar,
    tandaiSudahKirim,
    tandaiDanLog,
    getRecentLog,
    simulasi,
};
