'use strict';

/**
 * ─────────────────────────────────────────────────────
 *  FITUR   : Internet Speed Test
 *  Fungsi  : Ukur download, upload, dan ping ke server
 *            Cloudflare Speed (speed.cloudflare.com)
 *            menggunakan axios — tanpa binary eksternal.
 * ─────────────────────────────────────────────────────
 */

const axios = require('axios');

const CF_BASE    = 'https://speed.cloudflare.com';
const CF_DOWN    = `${CF_BASE}/__down`;
const CF_UP      = `${CF_BASE}/__up`;
const CF_META    = `${CF_BASE}/meta`;

const HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept'    : '*/*',
};

// ── PING ─────────────────────────────────────────────────────────────────────

async function ukurPing(ulang = 5) {
    const latencies = [];
    for (let i = 0; i < ulang; i++) {
        const t0 = Date.now();
        try {
            await axios.get(`${CF_BASE}/favicon.ico`, {
                headers : HEADERS,
                timeout : 5000,
                validateStatus: () => true,
            });
            latencies.push(Date.now() - t0);
        } catch (_) {}
        if (i < ulang - 1) await new Promise(r => setTimeout(r, 100));
    }
    if (!latencies.length) return null;
    latencies.sort((a, b) => a - b);
    const min    = latencies[0];
    const max    = latencies[latencies.length - 1];
    const avg    = Math.round(latencies.reduce((s, v) => s + v, 0) / latencies.length);
    const jitter = max - min;
    return { min, max, avg, jitter };
}

// ── DOWNLOAD ──────────────────────────────────────────────────────────────────

async function ukurDownload() {
    // Unduh 3 file berbeda ukuran secara berurutan, ambil yang terbaik
    const ukuranList = [
        { bytes: 10_000_000, label: '10MB'  },
        { bytes: 25_000_000, label: '25MB'  },
        { bytes: 100_000_000, label: '100MB' },
    ];

    const hasilMbps = [];

    for (const { bytes } of ukuranList) {
        try {
            const t0 = Date.now();
            const resp = await axios.get(`${CF_DOWN}?bytes=${bytes}`, {
                headers     : HEADERS,
                timeout     : 20000,
                responseType: 'arraybuffer',
            });
            const durMs    = Date.now() - t0;
            const bytesDapat = resp.data.byteLength || bytes;
            const mbps       = (bytesDapat * 8) / (durMs / 1000) / 1_000_000;
            hasilMbps.push(mbps);
        } catch (_) {
            break; // kalau file besar timeout, hentikan
        }
    }

    if (!hasilMbps.length) return null;
    return Math.max(...hasilMbps);
}

// ── UPLOAD ────────────────────────────────────────────────────────────────────

async function ukurUpload() {
    const ukuranList = [
        { bytes: 1_000_000,  label: '1MB'  },
        { bytes: 10_000_000, label: '10MB' },
    ];

    const hasilMbps = [];

    for (const { bytes } of ukuranList) {
        try {
            const data = Buffer.alloc(bytes, 'A');
            const t0   = Date.now();
            await axios.post(CF_UP, data, {
                headers: {
                    ...HEADERS,
                    'Content-Type'  : 'application/octet-stream',
                    'Content-Length': bytes,
                },
                timeout    : 20000,
                maxBodyLength: Infinity,
                validateStatus: () => true,
            });
            const durMs = Date.now() - t0;
            const mbps  = (bytes * 8) / (durMs / 1000) / 1_000_000;
            hasilMbps.push(mbps);
        } catch (_) {
            break;
        }
    }

    if (!hasilMbps.length) return null;
    return Math.max(...hasilMbps);
}

// ── META (ISP / Lokasi) ───────────────────────────────────────────────────────

async function ambilMeta() {
    try {
        // Cloudflare cdn-cgi/trace — plain text, selalu tersedia
        const { data } = await axios.get('https://cloudflare.com/cdn-cgi/trace', {
            headers: HEADERS,
            timeout: 5000,
        });
        const parse = (key) => {
            const m = String(data).match(new RegExp(`^${key}=(.+)$`, 'm'));
            return m ? m[1].trim() : '-';
        };
        const ip    = parse('ip');
        const negara = parse('loc');
        const colo  = parse('colo');
        // ISP dari endpoint ipinfo.io sebagai fallback ringan
        let isp = '-', kota = '-';
        try {
            const ipInfo = await axios.get(`https://ipinfo.io/${ip}/json`, {
                headers: { ...HEADERS, Accept: 'application/json' },
                timeout: 4000,
            });
            isp  = ipInfo.data?.org  || '-';
            kota = ipInfo.data?.city || '-';
        } catch (_) {
            kota = colo; // pakai kode datacenter Cloudflare sebagai fallback
        }
        return { ip, isp, kota, negara };
    } catch (_) {
        return { ip: '-', isp: '-', kota: '-', negara: '-' };
    }
}

// ── LABEL KUALITAS ────────────────────────────────────────────────────────────

function labelKualitas(mbps) {
    if (mbps === null || mbps === undefined) return { teks: 'Gagal', emoji: '❌' };
    if (mbps >= 100)  return { teks: 'Sangat Cepat', emoji: '🚀' };
    if (mbps >= 50)   return { teks: 'Cepat',        emoji: '⚡' };
    if (mbps >= 20)   return { teks: 'Normal',        emoji: '✅' };
    if (mbps >= 5)    return { teks: 'Lumayan',       emoji: '🟡' };
    return              { teks: 'Lambat',        emoji: '🐢' };
}

function labelPing(ms) {
    if (ms === null) return { teks: 'Gagal', emoji: '❌' };
    if (ms < 20)   return { teks: 'Excellent', emoji: '🟢' };
    if (ms < 50)   return { teks: 'Bagus',     emoji: '🟡' };
    if (ms < 100)  return { teks: 'Normal',    emoji: '🟠' };
    return           { teks: 'Tinggi',    emoji: '🔴' };
}

function formatMbps(mbps) {
    if (mbps === null) return 'Gagal';
    return mbps >= 1000
        ? `${(mbps / 1000).toFixed(2)} Gbps`
        : `${mbps.toFixed(2)} Mbps`;
}

// ── JALANKAN SPEEDTEST LENGKAP ────────────────────────────────────────────────

async function jalankanSpeedtest() {
    const mulai = Date.now();

    // Semua berjalan berurutan supaya tidak rebutan bandwidth
    const meta     = await ambilMeta();
    const pingData = await ukurPing(5);
    const dlMbps   = await ukurDownload();
    const ulMbps   = await ukurUpload();

    const durasi = ((Date.now() - mulai) / 1000).toFixed(1);

    return {
        meta,
        ping    : pingData,
        download: dlMbps,
        upload  : ulMbps,
        durasi,
    };
}

// ── FORMAT CAPTION ────────────────────────────────────────────────────────────

const SEP  = '━━━━━━━━━━━━━━━━━━━━';
const SEP2 = '┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄';

function buatCaption(hasil) {
    const { meta, ping, download, upload, durasi } = hasil;

    const dl      = labelKualitas(download);
    const ul      = labelKualitas(upload);
    const pg      = labelPing(ping?.avg ?? null);

    const waktu   = new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });

    const dlTeks  = download !== null ? `${formatMbps(download)}  ${dl.emoji} _${dl.teks}_` : '❌ Gagal';
    const ulTeks  = upload   !== null ? `${formatMbps(upload)}  ${ul.emoji} _${ul.teks}_`   : '❌ Gagal';

    const pingBaris = ping
        ? `${ping.avg} ms  ${pg.emoji} _${pg.teks}_\n` +
          `├ 📉 *Min*    : ${ping.min} ms\n` +
          `├ 📈 *Max*    : ${ping.max} ms\n` +
          `╰ 〰️ *Jitter* : ${ping.jitter} ms`
        : '❌ Gagal';

    return (
        `🌐 *INTERNET SPEED TEST*\n` +
        `${SEP}\n\n` +
        `📥 *Download*\n` +
        `╰ ${dlTeks}\n\n` +
        `📤 *Upload*\n` +
        `╰ ${ulTeks}\n\n` +
        `🏓 *Ping*\n` +
        `├ ⚡ *Avg*    : ${pingBaris}\n\n` +
        `${SEP}\n` +
        `📋 *Info Koneksi*\n` +
        `${SEP2}\n` +
        `├ 🌍 *Server*  : speed.cloudflare.com\n` +
        `├ 🏢 *ISP*     : ${meta.isp}\n` +
        `├ 📍 *Lokasi*  : ${meta.kota}, ${meta.negara}\n` +
        `╰ 🔌 *IP*      : ${meta.ip}\n` +
        `${SEP}\n` +
        `⏱️ _Selesai dalam ${durasi}s · ${waktu} WIB_`
    );
}

// ── SIMULASI ──────────────────────────────────────────────────────────────────

async function simulasi() {
    const hasil   = await jalankanSpeedtest();
    const caption = buatCaption(hasil);
    return { caption, hasil };
}

// ── EXPORT ────────────────────────────────────────────────────────────────────

module.exports = {
    jalankanSpeedtest,
    buatCaption,
    simulasi,
    ukurPing,
    ukurDownload,
    ukurUpload,
    ambilMeta,
    labelKualitas,
    labelPing,
    formatMbps,
};
