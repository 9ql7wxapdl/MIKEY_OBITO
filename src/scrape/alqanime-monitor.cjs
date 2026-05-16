'use strict';

/**
 * ─────────────────────────────────────────────────────
 *  FITUR   : Alqanime.net Realtime Monitor
 *  Fungsi  : Pantau rilisan episode Sub Indo terbaru
 *            dari alqanime.net (via r.jina.ai bypass CF).
 *            Thumbnail diambil langsung dari alqanime.net.
 *  Sumber  : alqanime.cjs
 * ─────────────────────────────────────────────────────
 */

const path  = require('path');
const fs    = require('fs');

const DIR_DATA    = path.join(process.cwd(), 'data', 'alqanimenotif');
const FILE_DATA   = path.join(DIR_DATA, 'state.json');
const FILE_LOG    = path.join(DIR_DATA, 'log.json');
const FILE_CONFIG = path.join(process.cwd(), 'config.json');
fs.mkdirSync(DIR_DATA, { recursive: true });

// Buffer waktu (ms) yang ditambahkan ke lastCheckTime saat menghitung batas usia post
// Mencegah post yang terbit tepat di batas window terlewat akibat latensi jaringan
const BUFFER_MS     = 3 * 60 * 1000;   // 3 menit
// Berapa lama (ms) post gagal-fetch akan dicoba ulang sebelum diabaikan permanen
const RETRY_TTL_MS  = 30 * 60 * 1000;  // 30 menit
// Jangkauan awal (ms) saat belum ada lastCheckTime (misal: bot baru start)
const INIT_WINDOW_MS = 30 * 60 * 1000; // 30 menit

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



// ── PENGATURAN GRUP ───────────────────────────────────────────────────────────

function getEnabledGroups() {
    const cfg    = bacaConfig();
    const groups = cfg?.alqanimenotif?.groups || {};
    return Object.entries(groups)
        .filter(([, v]) => v?.enabled === true)
        .map(([jid]) => jid);
}

function setGroupEnabled(jid, enabled) {
    const cfg = bacaConfig();
    if (!cfg.alqanimenotif)        cfg.alqanimenotif        = { groups: {} };
    if (!cfg.alqanimenotif.groups) cfg.alqanimenotif.groups = {};
    cfg.alqanimenotif.groups[jid] = { enabled, diubahPada: Date.now() };
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
//
// Menggunakan lastCheckTime (disimpan di state.json) sebagai penanda kapan terakhir
// kali cek dilakukan — sama seperti animasu.cjs. Sehingga tidak ada episode yang
// terlewat meski bot restart. idGagal dicoba ulang tiap siklus selama maks
// RETRY_TTL_MS (30 menit) sebelum diabaikan permanen.

async function cariEpisodeBaru() {
    const { getLatestAlqanime, getDetailAlqanime } = require('./alqanime.cjs');

    const now  = Date.now();
    const data = bacaData();

    // Simpan apakah ini first run SEBELUM menimpa lastCheckTime
    const isFirstRun = !data.lastCheckTime;

    // Simpan waktu check sekarang SEBELUM proses
    // (agar check berikutnya punya referensi waktu yang akurat — sama seperti animasu)
    data.lastCheckTime = now;
    if (!data.idTerkirim) data.idTerkirim = [];
    if (!data.idGagal)    data.idGagal    = [];
    simpanData(data);

    const baru        = [];
    const idGagalBaru = [];

    // ── Retry gagal sebelumnya ─────────────────────────────────────────────────
    for (const gagal of (data.idGagal || [])) {
        if (sudahDikirim(gagal.id)) continue;

        const usiaGagal = now - new Date(gagal.pertamaGagal).getTime();
        if (usiaGagal > RETRY_TTL_MS) {
            console.log(`[AlqanimeNotif] ⏭️ Retry timeout: "${gagal.judul}" ep ${gagal.epNum} diabaikan`);
            tandaiSudahKirim(gagal.id);
            continue;
        }

        try {
            const detail  = await getDetailAlqanime(gagal.url);
            const item    = {
                id       : gagal.id,
                url      : gagal.url,
                judul    : gagal.judul,
                epNum    : gagal.epNum,
                thumbnail: detail.thumbnail || gagal.thumbnail,
                ...detail,
            };
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

    // ── Pertama kali bot jalan (tidak ada lastCheckTime sebelumnya) ────────────
    // Tandai semua card saat ini sebagai seen, jangan kirim
    // Sama seperti animasu: hindari flood notif saat bot baru start
    if (isFirstRun) {
        console.log(`[AlqanimeNotif] 🚀 First run — tandai ${cards.length} card sebagai seen`);
        const df = bacaData();
        for (const card of cards) {
            const { epNum } = parseJudulEp(card.title || '');
            const id = buatId(card.url, epNum);
            if (!df.idTerkirim.includes(String(id))) {
                df.idTerkirim.unshift(String(id));
            }
        }
        df.idGagal = idGagalBaru;
        simpanData(df);
        return [];
    }

    // ── Run normal ─────────────────────────────────────────────────────────────
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
            baru.push(baseItem);
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

    // Simpan antrian retry terbaru
    const dataFinal = bacaData();
    dataFinal.idGagal = idGagalBaru;
    simpanData(dataFinal);

    return baru;
}

// ── SIMULASI ──────────────────────────────────────────────────────────────────

async function simulasi() {
    const { getRilisanTerbaru, getDetailAlqanime } = require('./alqanime.cjs');

    const cards = await getRilisanTerbaru();
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

    const caption   = buatCaption(baseItem);
    const urlGambar = baseItem.thumbnail || null;
    return { caption, urlGambar };
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
        .split('\n').map(b => `> ${b}`).join('\n');

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

    let dlBlok = '';
    if (episodes.length) {
        const epTerbaru    = episodes[0];
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
