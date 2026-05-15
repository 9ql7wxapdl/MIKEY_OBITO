'use strict';

/**
 * ─────────────────────────────────────────────────────
 *  FITUR   : Alqanime.net Realtime Monitor
 *  Fungsi  : Pantau rilisan episode Sub Indo terbaru
 *            dari alqanime.net (via r.jina.ai bypass CF).
 *            Thumbnail diambil dari MyAnimeList (MAL)
 *            via Jikan API — kualitas jernih & HD.
 *  Sumber  : alqanime.cjs + Jikan (api.jikan.moe)
 * ─────────────────────────────────────────────────────
 */

const axios = require('axios');
const path  = require('path');
const fs    = require('fs');

const DIR_DATA    = path.join(process.cwd(), 'data', 'alqanimenotif');
const FILE_DATA   = path.join(DIR_DATA, 'state.json');
const FILE_LOG    = path.join(DIR_DATA, 'log.json');
const FILE_MAL    = path.join(DIR_DATA, 'mal_cache.json');
const FILE_CONFIG = path.join(process.cwd(), 'config.json');
fs.mkdirSync(DIR_DATA, { recursive: true });

const RETRY_TTL_MS  = 30 * 60 * 1000;  // 30 menit
const MAL_CACHE_TTL = 7 * 24 * 3600 * 1000; // 7 hari

const JINA_BASE = 'https://r.jina.ai';
const HEADERS   = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept'    : 'text/plain, */*',
    'Accept-Language': 'id-ID,id;q=0.9,en;q=0.8',
};

// ── BACA / SIMPAN DATA ────────────────────────────────────────────────────────

function bacaData() {
    try {
        if (fs.existsSync(FILE_DATA)) return JSON.parse(fs.readFileSync(FILE_DATA, 'utf-8'));
    } catch (_) {}
    return { idTerkirim: [], idGagal: [], firstRun: false };
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

// ── MAL THUMBNAIL CACHE (disk) ────────────────────────────────────────────────

function bacaMalCache() {
    try {
        if (fs.existsSync(FILE_MAL)) return JSON.parse(fs.readFileSync(FILE_MAL, 'utf-8'));
    } catch (_) {}
    return {};
}

function simpanMalCache(cache) {
    try { fs.writeFileSync(FILE_MAL, JSON.stringify(cache, null, 2), 'utf-8'); } catch (_) {}
}

// Bersihkan judul anime agar cocok untuk pencarian MAL
function bersihkanJudulMAL(judul) {
    return judul
        .replace(/\s*Sub\s*Indo\s*/gi, '')
        .replace(/\s*Uncensored\s*/gi, '')
        .replace(/\s*\(Dub\)\s*/gi, '')
        .replace(/\s*Episode\s+\(?\d+\)?\s*/gi, '')
        .replace(/\s*-\s*Alqanime\s*$/gi, '')
        .replace(/\s+/g, ' ')
        .trim();
}

// Ambil thumbnail HD dari MyAnimeList via Jikan API
// Fallback: Jina.ai ke halaman MAL search
async function ambilThumbnailMAL(judul) {
    const key   = bersihkanJudulMAL(judul).toLowerCase();
    if (!key) return null;

    // Cek cache dulu
    const cache = bacaMalCache();
    if (cache[key] && (Date.now() - cache[key].cachedAt) < MAL_CACHE_TTL) {
        console.log(`[AlqanimeNotif] 🖼️ MAL cache hit: "${key}" → ${cache[key].url}`);
        return cache[key].url;
    }

    // ── Coba Jikan API (api.jikan.moe) ────────────────────────────────────────
    try {
        const q   = encodeURIComponent(bersihkanJudulMAL(judul));
        const res = await axios.get(
            `https://api.jikan.moe/v4/anime?q=${q}&limit=3&sfw=false`,
            { headers: { 'User-Agent': 'WilyBot/1.0' }, timeout: 15000 }
        );
        const list = res.data?.data || [];

        // Cari yang judulnya paling cocok (exact atau substring)
        const titleClean = bersihkanJudulMAL(judul).toLowerCase();
        let best = list.find(a =>
            (a.title || '').toLowerCase().includes(titleClean) ||
            titleClean.includes((a.title || '').toLowerCase())
        ) || list[0];

        const imgUrl = best?.images?.jpg?.large_image_url || best?.images?.jpg?.image_url;
        if (imgUrl) {
            console.log(`[AlqanimeNotif] 🖼️ MAL Jikan OK: "${key}" → ${imgUrl}`);
            cache[key] = { url: imgUrl, malId: best.mal_id, cachedAt: Date.now() };
            simpanMalCache(cache);
            return imgUrl;
        }
    } catch (e) {
        console.warn(`[AlqanimeNotif] ⚠️ Jikan gagal untuk "${key}":`, e?.message);
    }

    // ── Fallback: Jina.ai ke halaman MAL search ───────────────────────────────
    try {
        const q   = encodeURIComponent(bersihkanJudulMAL(judul));
        const res = await axios.get(
            `${JINA_BASE}/https://myanimelist.net/anime.php?q=${q}&cat=anime`,
            { headers: HEADERS, timeout: 20000 }
        );
        const md = res.data || '';
        // Cari URL gambar MAL cdn di markdown
        const m  = md.match(/https:\/\/(?:cdn\.)?myanimelist\.net\/images\/anime\/[^\s\)\"']+\.jpg/i);
        if (m) {
            // Ubah ke versi large (suffix 'l')
            const imgUrl = m[0].replace(/\.jpg$/i, 'l.jpg');
            console.log(`[AlqanimeNotif] 🖼️ MAL Jina OK: "${key}" → ${imgUrl}`);
            cache[key] = { url: imgUrl, malId: null, cachedAt: Date.now() };
            simpanMalCache(cache);
            return imgUrl;
        }
    } catch (e) {
        console.warn(`[AlqanimeNotif] ⚠️ Jina fallback gagal untuk "${key}":`, e?.message);
    }

    console.warn(`[AlqanimeNotif] ❌ Tidak dapat thumbnail MAL untuk "${key}"`);
    return null;
}

// ── PENGATURAN GRUP ───────────────────────────────────────────────────────────

function getEnabledGroups() {
    const cfg    = bacaConfig();
    const groups = cfg?.alqanime?.groups || {};
    return Object.entries(groups)
        .filter(([, v]) => v?.enabled === true)
        .map(([jid]) => jid);
}

function setGroupEnabled(jid, enabled) {
    const cfg = bacaConfig();
    if (!cfg.alqanime)        cfg.alqanime        = { groups: {} };
    if (!cfg.alqanime.groups) cfg.alqanime.groups = {};
    cfg.alqanime.groups[jid] = { enabled, diubahPada: Date.now() };
    simpanConfig(cfg);
}

// ── HELPER: PARSE JUDUL & NOMOR EPISODE ───────────────────────────────────────

function parseJudulEp(titleRaw) {
    const epM   = (titleRaw || '').match(/Episode\s+\(?(\d+)\)?/i);
    const epNum = epM ? parseInt(epM[1]) : 0;
    const judul = (titleRaw || '')
        .replace(/\s*Episode\s+\(?\d+\)?\s*/gi, '')
        .replace(/\s*Sub\s*Indo\s*Uncensored\s*/gi, '')
        .replace(/\s*Sub\s*Indo\s*/gi, '')
        .replace(/\s*Uncensored\s*$/gi, '')
        .replace(/\s*-\s*Alqanime\s*$/gi, '')
        // Perbaiki kasus tanpa spasi sebelum kata (misal: "TitleSub" → "Title")
        .replace(/([a-z])([A-Z])/g, '$1 $2')
        .replace(/\s{2,}/g, ' ')
        .trim();
    return { judul, epNum };
}

function buatId(url, epNum) {
    const slug = (url || '').replace(/^https?:\/\/alqanime\.net\//, '').replace(/\/+$/, '');
    return `${slug}::${epNum}`;
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
        if (data.idTerkirim.length > 500) data.idTerkirim = data.idTerkirim.slice(0, 500);
        simpanData(data);
    }
}

function tandaiDanLog(item, grupList) {
    tandaiSudahKirim(item.id);
    try {
        const log = bacaLog();
        if (!Array.isArray(log.terkirim)) log.terkirim = [];
        const sudahAda = log.terkirim.some(e => String(e.id) === String(item.id));
        if (!sudahAda) {
            log.terkirim.unshift({
                id         : String(item.id),
                judul      : item.judul || '-',
                epNum      : item.epNum || 0,
                waktuKirim : new Date().toISOString(),
                grupCount  : grupList.length,
                grupList,
                thumbnail  : item.malThumbnail || item.thumbnail || null,
                url        : item.url || null,
            });
            if (log.terkirim.length > 300) log.terkirim = log.terkirim.slice(0, 300);
            simpanLog(log);
        }
    } catch (e) {
        console.warn('[AlqanimeNotif] Gagal simpan log:', e?.message);
    }
}

function getRecentLog(jumlah = 20) {
    return (bacaLog().terkirim || []).slice(0, jumlah);
}

// ── ENRICH: TAMBAHKAN MAL THUMBNAIL KE ITEM ──────────────────────────────────

async function enrichDenganMAL(item) {
    const malThumb = await ambilThumbnailMAL(item.judul || '');
    // Ambil malUrl dari cache (malId disimpan saat Jikan berhasil)
    const key   = bersihkanJudulMAL(item.judul || '').toLowerCase();
    const cache = bacaMalCache();
    const malId = cache[key]?.malId;
    const malUrl = malId ? `https://myanimelist.net/anime/${malId}` : null;
    return { ...item, malThumbnail: malThumb || item.thumbnail || null, malUrl };
}

// ── CARI EPISODE BARU ─────────────────────────────────────────────────────────

async function cariEpisodeBaru() {
    const { getLatestAlqanime, getDetailAlqanime } = require('./alqanime.cjs');
    const data = bacaData();
    const baru = [];
    const idGagalBaru = [];

    // ── Retry gagal sebelumnya ─────────────────────────────────────────────────
    for (const gagal of (data.idGagal || [])) {
        if (sudahDikirim(gagal.id)) continue;
        if ((Date.now() - new Date(gagal.pertamaGagal).getTime()) > RETRY_TTL_MS) {
            console.log(`[AlqanimeNotif] ⏭️ Retry timeout: "${gagal.judul}" ep ${gagal.epNum} dilewati`);
            tandaiSudahKirim(gagal.id);
            continue;
        }
        try {
            const detail  = await getDetailAlqanime(gagal.url);
            const item    = await enrichDenganMAL({
                id       : gagal.id,
                url      : gagal.url,
                judul    : gagal.judul,
                epNum    : gagal.epNum,
                thumbnail: gagal.thumbnail,
                ...detail,
            });
            console.log(`[AlqanimeNotif] 🔄 Retry berhasil: "${gagal.judul}" ep ${gagal.epNum}`);
            baru.push(item);
        } catch (e) {
            console.warn(`[AlqanimeNotif] 🔄 Retry masih gagal "${gagal.judul}":`, e?.message);
            idGagalBaru.push(gagal);
        }
    }

    // ── Fetch homepage ─────────────────────────────────────────────────────────
    let cards = [];
    try {
        cards = await getLatestAlqanime();
    } catch (e) {
        console.error('[AlqanimeNotif] ❌ Gagal fetch homepage:', e?.message);
    }

    // Pertama kali bot jalan: tandai semua seen, jangan kirim
    if (!data.firstRun) {
        console.log(`[AlqanimeNotif] 🚀 First run — tandai ${cards.length} card sebagai seen`);
        for (const card of cards) {
            const { epNum } = parseJudulEp(card.title || '');
            tandaiSudahKirim(buatId(card.url, epNum));
        }
        const df      = bacaData();
        df.firstRun   = true;
        df.idGagal    = idGagalBaru;
        simpanData(df);
        return [];
    }

    // Run normal
    for (const card of cards) {
        const { judul, epNum } = parseJudulEp(card.title || '');
        const id = buatId(card.url, epNum);
        if (sudahDikirim(id)) continue;

        try {
            const detail = await getDetailAlqanime(card.url);
            const { judul: judulD, epNum: epD } = parseJudulEp(detail.title || '');
            const baseItem = {
                id,
                url      : card.url,
                judul    : judulD || judul,
                epNum    : epD || epNum,
                thumbnail: detail.thumbnail || card.thumbnail,
                ...detail,
            };
            const item = await enrichDenganMAL(baseItem);
            baru.push(item);
        } catch (e) {
            console.warn(`[AlqanimeNotif] ❌ Gagal fetch detail "${judul}" ep ${epNum}:`, e?.message);
            idGagalBaru.push({
                id,
                url         : card.url,
                judul,
                epNum,
                thumbnail   : card.thumbnail,
                pertamaGagal: new Date().toISOString(),
            });
        }
    }

    const df   = bacaData();
    df.idGagal = idGagalBaru;
    simpanData(df);
    return baru;
}

// ── SIMULASI ──────────────────────────────────────────────────────────────────

async function simulasi() {
    const { getLatestAlqanime, getDetailAlqanime } = require('./alqanime.cjs');

    const cards = await getLatestAlqanime();
    if (!cards.length) throw new Error('Tidak ada rilisan terbaru dari alqanime.net');

    const card   = cards[0];
    const { judul, epNum } = parseJudulEp(card.title || '');
    const id     = buatId(card.url, epNum);
    const detail = await getDetailAlqanime(card.url);
    const { judul: judulD, epNum: epD } = parseJudulEp(detail.title || '');

    const baseItem = {
        id,
        url      : card.url,
        judul    : judulD || judul,
        epNum    : epD || epNum,
        thumbnail: detail.thumbnail || card.thumbnail,
        ...detail,
    };

    const item    = await enrichDenganMAL(baseItem);
    const caption = buatCaption(item);

    // Prioritas gambar: MAL thumbnail > alqanime thumbnail
    const urlGambar = item.malThumbnail || item.thumbnail || null;
    return { item, caption, urlGambar, malThumbnail: item.malThumbnail, alqThumbnail: item.thumbnail, malUrl: item.malUrl };
}

// ── FORMAT CAPTION ────────────────────────────────────────────────────────────

const SEP  = '━━━━━━━━━━━━━━━━━━';
const SEP2 = '┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄';

function potongSinopsis(teks) {
    return (teks || '-').trim();
}

function buatBarisInfo(items) {
    const valid = items.filter(([, v]) => v !== null && v !== undefined && v !== '' && v !== '-');
    return valid.map(([label, val], i) => {
        const prefix = i === valid.length - 1 ? '╰' : '├';
        return `${prefix} ${label} : ${val}`;
    }).join('\n');
}

function buatCaption(data) {
    const {
        judul, epNum,
        info = {}, sinopsis, genres = [], episodes = [], url,
    } = data;

    const sekarang    = new Date();
    const opsiHari    = { timeZone: 'Asia/Jakarta', weekday: 'long' };
    const opsiTgl     = { timeZone: 'Asia/Jakarta', day: '2-digit', month: 'long', year: 'numeric' };
    const opsiJam     = { timeZone: 'Asia/Jakarta', hour: '2-digit', minute: '2-digit', hour12: false };
    const namaHari    = sekarang.toLocaleDateString('id-ID', opsiHari);
    const tglLengkap  = sekarang.toLocaleDateString('id-ID', opsiTgl);
    const jamMenit    = sekarang.toLocaleTimeString('id-ID', opsiJam).replace('.', ':');
    const headerWaktu = `${namaHari}, ${tglLengkap} · ${jamMenit} WIB`;

    const ep        = epNum || '?';
    const totalSeri = info.Episode ? parseInt(info.Episode) || 0 : 0;
    const epHeader  = totalSeri ? `${ep}/${totalSeri}` : String(ep);

    const sinopsisBlock = potongSinopsis(sinopsis)
        .split('\n')
        .filter(l => l.trim())
        .map(b => `> ${b}`)
        .join('\n');

    const genreStr = genres.length ? `_${genres.slice(0, 5).join(', ')}_` : null;

    const seksi1 = buatBarisInfo([
        ['🗂️ *Tipe*     ', info.Tipe     || null],
        ['⏱️ *Durasi*   ', info.Durasi   || null],
        ['📦 *Episode*  ', totalSeri ? `${ep}/${totalSeri}` : (ep !== '?' ? String(ep) : null)],
        ['🗓️ *Dirilis*  ', info.Dirilis  || null],
        ['🌸 *Musim*    ', info.Musim    || null],
        ['📡 *Status*   ', info.Status   || null],
        ['🏢 *Studio*   ', info.Studio   || null],
        ['🗣️ *Subtitle* ', info.Subtitle || null],
        ['✏️ *Credit*   ', info.Credit   || null],
    ]);

    const seksi2 = buatBarisInfo([
        ['⭐ *Score*    ', info.Score ? `${info.Score}/10` : null],
        ['🎭 *Genre*    ', genreStr],
        ['👥 *Casts*    ', info.Casts   || null],
    ]);

    const seksi3 = buatBarisInfo([
        ['📤 *Oleh*        ', info['Diposting oleh']  || null],
        ['🗓️ *Diposting*   ', info['Diposting pada']  || null],
        ['🔄 *Diperbarui*  ', info['Diperbarui pada'] || null],
    ]);

    // Download links: episode terbaru, max 4 resolusi
    let dlBlok = '';
    if (episodes.length) {
        const epTerbaru  = episodes[0];
        const resolusiList = Object.entries(epTerbaru.links || {}).slice(0, 4);
        if (resolusiList.length) {
            dlBlok += `\n${SEP}\n`;
            dlBlok += `📥 *DOWNLOAD EP ${epTerbaru.episode}*\n`;
            dlBlok += `${SEP2}\n`;
            for (const [res, hosts] of resolusiList) {
                const hostStr = hosts.slice(0, 3).map(h => `[${h.host}](${h.url})`).join('  ');
                dlBlok += `├ ${res.toUpperCase()} → ${hostStr}\n`;
            }
            dlBlok = dlBlok.trimEnd();
        }
    }

    const judulAlt = info.judulAlt ? `_${info.judulAlt}_\n` : '';

    return (
        `🔴 *RILISAN BARU ALQANIME!*\n` +
        `${SEP}\n` +
        `📅 _${headerWaktu}_\n` +
        `${SEP}\n\n` +
        `🎌 *${judul}*\n` +
        (judulAlt ? `${judulAlt}` : '') +
        `\n📺 *Episode ${epHeader}*\n` +
        `\n📖 *Sinopsis*\n` +
        `${sinopsisBlock}\n\n` +
        `${SEP}\n` +
        `📋 *Info Anime*\n` +
        `${SEP2}\n` +
        `${seksi1}\n` +
        `${SEP2}\n` +
        `${seksi2}\n` +
        (seksi3 ? `${SEP2}\n${seksi3}\n` : '') +
        `${SEP}\n` +
        `▶️ *Tonton* : ${url}\n` +
        `🔗 *Source* : alqanime.net` +
        dlBlok
    );
}

// Prioritaskan MAL thumbnail (jernih) > alqanime thumbnail (fallback)
function ambilUrlGambar(data) {
    return data?.malThumbnail || data?.thumbnail || null;
}

// ── KIRIM INTERAKTIF (dengan tombol URL via Button class) ─────────────────────

function buatBodyRingkas(item) {
    const { judul, epNum, info = {}, genres = [] } = item;

    const ep        = epNum || '?';
    const totalSeri = info.Episode ? parseInt(info.Episode) || 0 : 0;
    const epHeader  = totalSeri ? `${ep}/${totalSeri}` : String(ep);

    const sekarang   = new Date();
    const opsiHari   = { timeZone: 'Asia/Jakarta', weekday: 'long' };
    const opsiTgl    = { timeZone: 'Asia/Jakarta', day: '2-digit', month: 'long', year: 'numeric' };
    const opsiJam    = { timeZone: 'Asia/Jakarta', hour: '2-digit', minute: '2-digit', hour12: false };
    const namaHari   = sekarang.toLocaleDateString('id-ID', opsiHari);
    const tglLengkap = sekarang.toLocaleDateString('id-ID', opsiTgl);
    const jamMenit   = sekarang.toLocaleTimeString('id-ID', opsiJam).replace('.', ':');

    const baris = [];
    if (info.Tipe)   baris.push(`🗂️ ${info.Tipe}`);
    if (info.Durasi) baris.push(`⏱️ ${info.Durasi}`);
    if (info.Studio) baris.push(`🏢 ${info.Studio}`);
    if (info.Status) baris.push(`📡 ${info.Status}`);
    const scoreGenre = [
        info.Score ? `⭐ ${info.Score}/10` : null,
        genres.length ? `🎭 ${genres.slice(0, 3).join(', ')}` : null,
    ].filter(Boolean).join(' · ');

    return (
        `🔴 *RILISAN BARU — ALQANIME*\n` +
        `━━━━━━━━━━━━━━━━━━\n` +
        `🎌 *${judul || '?'}*\n` +
        `📺 Episode *${epHeader}*\n` +
        (baris.length ? `\n${baris.join('\n')}\n` : '') +
        (scoreGenre   ? `${scoreGenre}\n` : '') +
        `━━━━━━━━━━━━━━━━━━\n` +
        `📅 _${namaHari}, ${tglLengkap} · ${jamMenit} WIB_`
    );
}

async function kirimInteraktif(item, jid, hisoka) {
    try {
        const { Button } = require('../lib/Button.cjs');

        const body      = buatBodyRingkas(item);
        const urlGambar = ambilUrlGambar(item);

        const btn = new Button()
            .setBody(body)
            .setFooter('⚡ alqanime.net');

        // Tombol 1 — cta_url: buka halaman episode (tonton + download)
        btn.addUrl('▶️ Tonton / Download', item.url || 'https://alqanime.net', false);

        // Tombol 2 — cta_copy: salin link download langsung resolusi terbaik
        const epTerbaru = (item.episodes || [])[0];
        if (epTerbaru?.links) {
            let dlUrl = null;
            for (const res of ['720p', '480p', '1080p', '360p']) {
                if (epTerbaru.links[res]) { dlUrl = epTerbaru.links[res]; break; }
            }
            if (!dlUrl) {
                const firstKey = Object.keys(epTerbaru.links)[0];
                if (firstKey) dlUrl = epTerbaru.links[firstKey];
            }
            if (dlUrl) btn.addCopy('⬇️ Salin Link Download', dlUrl);
        }

        // Tombol 3 — cta_url: halaman MyAnimeList (jika tersedia)
        if (item.malUrl) {
            btn.addUrl('🌟 Info MyAnimeList', item.malUrl, false);
        }

        if (urlGambar) {
            try {
                const imgBuf = await axios.get(urlGambar, { responseType: 'arraybuffer', timeout: 20000 })
                    .then(r => Buffer.from(r.data));
                btn.setImage(imgBuf);
            } catch (imgErr) {
                console.warn('[AlqanimeNotif] ⚠️ Gambar header gagal:', imgErr?.message);
            }
        }

        return await btn.run(jid, hisoka);

    } catch (e) {
        console.warn('[AlqanimeNotif] ⚠️ Interactive gagal, fallback biasa:', e?.message);
        const caption   = buatCaption(item);
        const urlGambar = ambilUrlGambar(item);
        if (urlGambar) {
            return hisoka.sendMessage(jid, { image: { url: urlGambar }, caption });
        }
        return hisoka.sendMessage(jid, { text: caption });
    }
}

// ── EXPORT ────────────────────────────────────────────────────────────────────

module.exports = {
    getEnabledGroups,
    setGroupEnabled,
    cariEpisodeBaru,
    buatCaption,
    ambilUrlGambar,
    kirimInteraktif,
    tandaiSudahKirim,
    tandaiDanLog,
    getRecentLog,
    simulasi,
    ambilThumbnailMAL,
};
