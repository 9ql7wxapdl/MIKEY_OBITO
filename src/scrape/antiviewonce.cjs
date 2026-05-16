'use strict';

/**
 * ─────────────────────────────────────────────────────
 *  FITUR   : Anti View Once
 *  Fungsi  : Deteksi otomatis pesan sekali lihat di
 *            grup/chat, replay media tanpa flag viewOnce,
 *            dan log realtime siapa yang mengirim.
 *  Command : .antiviewonce on/off/status/log
 * ─────────────────────────────────────────────────────
 */

const fs   = require('fs');
const path = require('path');

const FILE_CONFIG = path.join(process.cwd(), 'config.json');
const FILE_LOG    = path.join(process.cwd(), 'data', 'antiviewonce', 'log.json');
fs.mkdirSync(path.join(process.cwd(), 'data', 'antiviewonce'), { recursive: true });

// ── CONFIG ────────────────────────────────────────────────────────────────────

function bacaConfig() {
    try {
        if (fs.existsSync(FILE_CONFIG)) return JSON.parse(fs.readFileSync(FILE_CONFIG, 'utf-8'));
    } catch (_) {}
    return {};
}

function simpanConfig(cfg) {
    try { fs.writeFileSync(FILE_CONFIG, JSON.stringify(cfg, null, 2), 'utf-8'); } catch (_) {}
}

function isEnabled(jid) {
    const cfg = bacaConfig();
    return cfg?.antiviewonce?.groups?.[jid]?.enabled === true;
}

function setEnabled(jid, enabled) {
    const cfg = bacaConfig();
    if (!cfg.antiviewonce)        cfg.antiviewonce        = { groups: {} };
    if (!cfg.antiviewonce.groups) cfg.antiviewonce.groups = {};
    cfg.antiviewonce.groups[jid] = { enabled, diubahPada: Date.now() };
    simpanConfig(cfg);
}

function getEnabledGroups() {
    const cfg    = bacaConfig();
    const groups = cfg?.antiviewonce?.groups || {};
    return Object.entries(groups)
        .filter(([, v]) => v?.enabled === true)
        .map(([jid]) => jid);
}

// ── LOG ───────────────────────────────────────────────────────────────────────

function bacaLog() {
    try {
        if (fs.existsSync(FILE_LOG)) return JSON.parse(fs.readFileSync(FILE_LOG, 'utf-8'));
    } catch (_) {}
    return { terdeteksi: [] };
}

function simpanLog(log) {
    try { fs.writeFileSync(FILE_LOG, JSON.stringify(log, null, 2), 'utf-8'); } catch (_) {}
}

function tambahLog(entry) {
    try {
        const log = bacaLog();
        if (!Array.isArray(log.terdeteksi)) log.terdeteksi = [];
        log.terdeteksi.unshift(entry);
        if (log.terdeteksi.length > 200) log.terdeteksi = log.terdeteksi.slice(0, 200);
        simpanLog(log);
    } catch (_) {}
}

function getLog(jumlah = 10) {
    return (bacaLog().terdeteksi || []).slice(0, jumlah);
}

// ── DETEKSI VIEW ONCE ─────────────────────────────────────────────────────────

const VO_TYPES    = ['viewOnceMessage', 'viewOnceMessageV2', 'viewOnceMessageV2Extension'];
const MEDIA_TYPES = ['imageMessage', 'videoMessage', 'audioMessage', 'documentMessage'];

function deteksiViewOnce(rawMessage) {
    const msg = rawMessage?.message || rawMessage || {};

    // Cek langsung di level message
    for (const voType of VO_TYPES) {
        if (msg[voType]?.message) {
            const inner = msg[voType].message;
            for (const mt of MEDIA_TYPES) {
                if (inner[mt]) return { voType, mediaType: mt, mediaMessage: inner[mt], innerMsg: inner };
            }
        }
    }

    // Wrapped dalam ephemeral
    if (msg.ephemeralMessage?.message) {
        const eph = msg.ephemeralMessage.message;
        for (const voType of VO_TYPES) {
            if (eph[voType]?.message) {
                const inner = eph[voType].message;
                for (const mt of MEDIA_TYPES) {
                    if (inner[mt]) return { voType, mediaType: mt, mediaMessage: inner[mt], innerMsg: inner };
                }
            }
        }
    }

    return null;
}

// ── FORMAT ────────────────────────────────────────────────────────────────────

const TIPE_LABEL = {
    imageMessage   : 'Foto',
    videoMessage   : 'Video',
    audioMessage   : 'Audio',
    documentMessage: 'Dokumen',
};

const TIPE_SIMBOL = {
    imageMessage   : '🖼',
    videoMessage   : '🎥',
    audioMessage   : '🎵',
    documentMessage: '📄',
};

function formatTanggal(ts) {
    try {
        return new Date(ts).toLocaleString('id-ID', {
            timeZone: 'Asia/Jakarta',
            weekday : 'long',
            day     : '2-digit',
            month   : 'long',
            year    : 'numeric',
            hour    : '2-digit',
            minute  : '2-digit',
            hour12  : false,
        }).replace('.', ':') + ' WIB';
    } catch (_) { return String(ts); }
}

function buatCaption(info) {
    const { senderName, senderNumber, groupName, isGroup, mediaType, waktu } = info;
    const tipe   = TIPE_LABEL[mediaType]  || 'Media';
    const simbol = TIPE_SIMBOL[mediaType] || '📨';
    const tgl    = formatTanggal(waktu);

    return (
        `# ◆ ANTI VIEW ONCE — TERDETEKSI\n` +
        `> ◈ _${tgl}_\n\n` +
        `### ${simbol} ${tipe} View Once\n` +
        `- *Dari*  : ${senderName} (+${senderNumber})\n` +
        (isGroup
            ? `- *Grup*  : ${groupName}\n`
            : `- *Chat*  : Private\n`) +
        `- *Tipe*  : ${tipe}\n\n` +
        `_Pesan sekali lihat berhasil dibuka otomatis_ ◆`
    );
}

// ── HANDLE (dipanggil dari event.js / message.js) ─────────────────────────────

async function handleViewOnce(hisoka, m) {
    if (!isEnabled(m.from)) return false;

    // Deteksi view once dari raw message
    const rawMsg = m.message || m.raw?.message || m.raw || {};
    const vo = deteksiViewOnce({ message: rawMsg });
    if (!vo) return false;

    try {
        const { downloadMediaMessage } = require('socketon');

        // Bangun pesan untuk download
        const dlMsg = {
            key    : m.key,
            message: { [vo.voType]: { message: vo.innerMsg } },
        };

        let buffer = null;

        // Coba download langsung
        try {
            buffer = await downloadMediaMessage(
                dlMsg, 'buffer', {},
                { logger: hisoka.logger }
            );
        } catch (_) {}

        // Fallback dengan reuploadRequest
        if (!buffer || buffer.length === 0) {
            buffer = await downloadMediaMessage(
                dlMsg, 'buffer', {},
                { logger: hisoka.logger, reuploadRequest: hisoka.updateMediaMessage }
            );
        }

        if (!buffer || buffer.length === 0) return false;

        // Info pengirim
        const senderNumber = (m.sender || '').split('@')[0].split(':')[0];
        const senderName   = m.pushName || senderNumber;
        const isGroup      = !!(m.isGroup ?? (m.from || '').endsWith('@g.us'));
        const groupName    = isGroup
            ? (typeof hisoka.getName === 'function' ? (hisoka.getName(m.from) || m.from) : m.from)
            : 'Private';

        const caption = buatCaption({ senderName, senderNumber, groupName, isGroup, mediaType: vo.mediaType, waktu: Date.now() });

        // Bangun payload kirim tanpa viewOnce
        const payload = { caption };
        if      (vo.mediaType === 'imageMessage')    payload.image    = buffer;
        else if (vo.mediaType === 'videoMessage')    payload.video    = buffer;
        else if (vo.mediaType === 'audioMessage')    { payload.audio = buffer; payload.mimetype = vo.mediaMessage?.mimetype || 'audio/mp4'; payload.ptt = false; }
        else if (vo.mediaType === 'documentMessage') {
            payload.document = buffer;
            payload.fileName = vo.mediaMessage?.fileName || 'dokumen';
            payload.mimetype = vo.mediaMessage?.mimetype || 'application/octet-stream';
        }

        await hisoka.sendMessage(m.from, payload, { quoted: m });

        // Log
        tambahLog({
            waktu    : new Date().toISOString(),
            sender   : senderNumber,
            nama     : senderName,
            grup     : isGroup ? m.from : null,
            namaGrup : isGroup ? groupName : null,
            mediaType: vo.mediaType,
        });

        return true;
    } catch (e) {
        console.warn('[AntiVO] gagal proses:', e?.message);
        return false;
    }
}

// ── SIMULASI ──────────────────────────────────────────────────────────────────

function simulasi() {
    const caption = buatCaption({
        senderName  : 'Budi Santoso',
        senderNumber: '6281234567890',
        groupName   : 'Grup Anime Weebs 🎌',
        isGroup     : true,
        mediaType   : 'imageMessage',
        waktu       : Date.now(),
    });

    const captionVideo = buatCaption({
        senderName  : 'Siti Rahayu',
        senderNumber: '6289876543210',
        groupName   : null,
        isGroup     : false,
        mediaType   : 'videoMessage',
        waktu       : Date.now(),
    });

    return { captionFoto: caption, captionVideo };
}

// ── EXPORT ────────────────────────────────────────────────────────────────────

module.exports = {
    isEnabled,
    setEnabled,
    getEnabledGroups,
    handleViewOnce,
    deteksiViewOnce,
    buatCaption,
    getLog,
    simulasi,
};
