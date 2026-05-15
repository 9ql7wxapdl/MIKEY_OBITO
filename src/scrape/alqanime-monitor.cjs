'use strict';

/**
 * ─────────────────────────────────────────────────────
 *  FITUR   : Alqanime.net Realtime Monitor
 *  Fungsi  : Pantau rilisan episode Sub Indo terbaru
 *            dari alqanime.net (via r.jina.ai bypass CF).
 *            Kirim notifikasi ke grup WA saat ada
 *            episode baru yang muncul di homepage.
 *  Sumber  : alqanime.cjs (getLatestAlqanime + getDetailAlqanime)
 * ─────────────────────────────────────────────────────
 */

const path = require('path');
const fs   = require('fs');

const FILE_DATA   = path.join(process.cwd(), 'data', 'alqanimenotif', 'state.json');
const FILE_LOG    = path.join(process.cwd(), 'data', 'alqanimenotif', 'log.json');
const FILE_CONFIG = path.join(process.cwd(), 'config.json');
fs.mkdirSync(path.join(process.cwd(), 'data', 'alqanimenotif'), { recursive: true });

// Berapa lama (ms) gagal-fetch akan dicoba ulang sebelum dilewati
const RETRY_TTL_MS = 30 * 60 * 1000; // 30 menit

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

// ── BACA / SIMPAN LOG ─────────────────────────────────────────────────────────

function bacaLog() {
    try {
        if (fs.existsSync(FILE_LOG)) return JSON.parse(fs.readFileSync(FILE_LOG, 'utf-8'));
    } catch (_) {}
    return { terkirim: [] };
}

function simpanLog(log) {
    try { fs.writeFileSync(FILE_LOG, JSON.stringify(log, null, 2), 'utf-8'); } catch (_) {}
}

// ── BACA / SIMPAN CONFIG ──────────────────────────────────────────────────────

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

// ── HELPER: PARSE JUDUL & NOMOR EPISODE DARI JUDUL CARD ───────────────────────

function parseJudulEp(titleRaw) {
    // Contoh: "Anime Name Episode (03) Sub Indo"
    const epM = titleRaw.match(/Episode\s+\(?(\d+)\)?/i);
    const epNum = epM ? parseInt(epM[1]) : 0;
    const judul = titleRaw
        .replace(/\s*Episode\s+\(?\d+\)?\s*/i, '')
        .replace(/\s*Sub\s*Indo\s*$/i, '')
        .replace(/\s*-\s*Alqanime\s*$/i, '')
        .trim();
    return { judul, epNum };
}

// Buat ID unik per entri: slug URL + nomor episode
function buatId(url, epNum) {
    const slug = (url || '').replace(/^https?:\/\/alqanime\.net\//, '').replace(/\/+$/, '');
    return `${slug}::${epNum}`;
}

// ── DEDUP ─────────────────────────────────────────────────────────────────────

function sudahDikirim(id) {
    const data = bacaData();
    return (data.idTerkirim || []).includes(String(id));
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
                thumbnail  : item.thumbnail || null,
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

// ── CARI EPISODE BARU ─────────────────────────────────────────────────────────

async function cariEpisodeBaru() {
    const { getLatestAlqanime, getDetailAlqanime } = require('./alqanime.cjs');
    const data = bacaData();
    const baru = [];
    const idGagalBaru = [];

    // ── Retry gagal sebelumnya ─────────────────────────────────────────────────
    for (const gagal of (data.idGagal || [])) {
        if (sudahDikirim(gagal.id)) continue;
        const usiaGagal = Date.now() - new Date(gagal.pertamaGagal).getTime();
        if (usiaGagal > RETRY_TTL_MS) {
            console.log(`[AlqanimeNotif] ⏭️ Retry timeout: "${gagal.judul}" ep ${gagal.epNum} dilewati`);
            tandaiSudahKirim(gagal.id);
            continue;
        }
        try {
            const detail = await getDetailAlqanime(gagal.url);
            console.log(`[AlqanimeNotif] 🔄 Retry berhasil: "${gagal.judul}" ep ${gagal.epNum}`);
            baru.push({
                id        : gagal.id,
                url       : gagal.url,
                judul     : gagal.judul,
                epNum     : gagal.epNum,
                thumbnail : gagal.thumbnail,
                ...detail,
            });
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

    // Pertama kali bot jalan: tandai semua card sebagai sudah kirim, jangan kirim
    if (!data.firstRun) {
        console.log(`[AlqanimeNotif] 🚀 First run — tandai ${cards.length} card sebagai seen`);
        for (const card of cards) {
            const { epNum } = parseJudulEp(card.title || '');
            const id = buatId(card.url, epNum);
            tandaiSudahKirim(id);
        }
        const dataFinal = bacaData();
        dataFinal.firstRun = true;
        dataFinal.idGagal  = idGagalBaru;
        simpanData(dataFinal);
        return [];
    }

    // Run normal: cek card yang belum pernah dikirim
    for (const card of cards) {
        const { judul, epNum } = parseJudulEp(card.title || '');
        const id = buatId(card.url, epNum);
        if (sudahDikirim(id)) continue;

        try {
            const detail = await getDetailAlqanime(card.url);
            // Override judul & epNum dari detail jika ada
            const { judul: judulDetail, epNum: epDetail } = parseJudulEp(detail.title || '');
            baru.push({
                id,
                url       : card.url,
                judul     : judulDetail || judul,
                epNum     : epDetail || epNum,
                thumbnail : detail.thumbnail || card.thumbnail,
                ...detail,
            });
        } catch (e) {
            console.warn(`[AlqanimeNotif] ❌ Gagal fetch detail "${judul}" ep ${epNum}:`, e?.message);
            idGagalBaru.push({
                id,
                url          : card.url,
                judul,
                epNum,
                thumbnail    : card.thumbnail,
                pertamaGagal : new Date().toISOString(),
            });
        }
    }

    const dataFinal = bacaData();
    dataFinal.idGagal = idGagalBaru;
    simpanData(dataFinal);

    return baru;
}

// ── SIMULASI ──────────────────────────────────────────────────────────────────

async function simulasi() {
    const { getLatestAlqanime, getDetailAlqanime } = require('./alqanime.cjs');
    const cards = await getLatestAlqanime();
    if (!cards.length) throw new Error('Tidak ada rilisan terbaru dari alqanime.net');

    const card = cards[0];
    const { judul, epNum } = parseJudulEp(card.title || '');
    const id     = buatId(card.url, epNum);
    const detail = await getDetailAlqanime(card.url);
    const { judul: judulDetail, epNum: epDetail } = parseJudulEp(detail.title || '');

    const item = {
        id,
        url       : card.url,
        judul     : judulDetail || judul,
        epNum     : epDetail || epNum,
        thumbnail : detail.thumbnail || card.thumbnail,
        ...detail,
    };

    const caption = buatCaption(item);
    return { caption, urlGambar: item.thumbnail || null };
}

// ── FORMAT CAPTION ────────────────────────────────────────────────────────────

const SEP  = '━━━━━━━━━━━━━━━━━━';
const SEP2 = '┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄';

function potongSinopsis(teks, maks = 350) {
    if (!teks || teks.length <= maks) return teks || '-';
    const potong    = teks.slice(0, maks);
    const lastSpace = potong.lastIndexOf(' ');
    return (lastSpace > 0 ? potong.slice(0, lastSpace) : potong) + '...';
}

function buatBarisInfo(items) {
    const valid = items.filter(([, val]) => val !== null && val !== undefined && val !== '' && val !== '-');
    return valid.map(([label, val], i) => {
        const prefix = i === valid.length - 1 ? '╰' : '├';
        return `${prefix} ${label} : ${val}`;
    }).join('\n');
}

function buatCaption(data) {
    const {
        judul, epNum, thumbnail,
        info = {}, sinopsis, genres = [], episodes = [], url,
    } = data;

    const sekarang   = new Date();
    const opsiHari   = { timeZone: 'Asia/Jakarta', weekday: 'long' };
    const opsiTgl    = { timeZone: 'Asia/Jakarta', day: '2-digit', month: 'long', year: 'numeric' };
    const opsiJam    = { timeZone: 'Asia/Jakarta', hour: '2-digit', minute: '2-digit', hour12: false };
    const namaHari   = sekarang.toLocaleDateString('id-ID', opsiHari);
    const tglLengkap = sekarang.toLocaleDateString('id-ID', opsiTgl);
    const jamMenit   = sekarang.toLocaleTimeString('id-ID', opsiJam).replace('.', ':');
    const headerWaktu = `${namaHari}, ${tglLengkap} · ${jamMenit} WIB`;

    const ep         = epNum || '?';
    const totalSeri  = info.Episode ? parseInt(info.Episode) || 0 : 0;
    const epHeader   = totalSeri ? `${ep}/${totalSeri}` : String(ep);

    const sinopsisBlock = potongSinopsis(sinopsis)
        .split('\n').map(b => `> ${b}`).join('\n');

    const genreStr = genres.length ? `_${genres.slice(0, 5).join(', ')}_` : null;

    const seksi1 = buatBarisInfo([
        ['🗂️ *Tipe*    ', info.Tipe    || null],
        ['⏱️ *Durasi*  ', info.Durasi  || null],
        ['📦 *Episode* ', totalSeri ? `${ep}/${totalSeri}` : (ep !== '?' ? `${ep}` : null)],
        ['🗓️ *Dirilis* ', info.Dirilis || null],
        ['🌸 *Musim*   ', info.Musim   || null],
        ['📡 *Status*  ', info.Status  || null],
        ['🏢 *Studio*  ', info.Studio  || null],
    ]);

    const seksi2 = buatBarisInfo([
        ['⭐ *Score*   ', info.Score   ? `${info.Score}/10` : null],
        ['🎭 *Genre*   ', genreStr],
    ]);

    // Download links (tampilkan episode terbaru saja, max 3 resolusi)
    let dlBlok = '';
    if (episodes.length) {
        const epTerbaru = episodes[0]; // episode list urutan terbaru
        dlBlok += `\n${SEP}\n`;
        dlBlok += `📥 *DOWNLOAD EP ${epTerbaru.episode}*\n`;
        dlBlok += `${SEP2}\n`;
        const resolusiList = Object.entries(epTerbaru.links || {}).slice(0, 4);
        for (const [res, hosts] of resolusiList) {
            const hostStr = hosts.slice(0, 3).map(h => `[${h.host}](${h.url})`).join('  ');
            dlBlok += `├ ${res.toUpperCase()} → ${hostStr}\n`;
        }
        dlBlok = dlBlok.trimEnd();
    }

    return (
        `🔴 *RILISAN BARU ALQANIME!*\n` +
        `${SEP}\n` +
        `📅 _${headerWaktu}_\n` +
        `${SEP}\n\n` +
        `🎌 *${judul}*\n` +
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
        `▶️ *Tonton* : ${url}\n` +
        `🔗 *Source* : alqanime.net` +
        dlBlok
    );
}

function ambilUrlGambar(data) {
    return data?.thumbnail || null;
}

// ── EXPORT ────────────────────────────────────────────────────────────────────

module.exports = {
    getEnabledGroups,
    setGroupEnabled,
    cariEpisodeBaru,
    buatCaption,
    ambilUrlGambar,
    tandaiSudahKirim,
    tandaiDanLog,
    getRecentLog,
    simulasi,
};
