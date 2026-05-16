'use strict';

/**
 * ─────────────────────────────────────────────────────
 *  Anti View Once Handler (ESM)
 *  Pola persis seperti antidelete.js
 *  Dipanggil dari index.js via getHandler('antiviewonce')
 *  pada event messages.upsert
 * ─────────────────────────────────────────────────────
 */

import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';
const _require = createRequire(import.meta.url);
const { getContentType, downloadMediaMessage, isJidGroup } = _require('socketon');

const CONFIG_PATH = path.join(process.cwd(), 'config.json');
const LOG_PATH    = path.join(process.cwd(), 'data', 'antiviewonce', 'log.json');

fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });

// ── CONFIG ────────────────────────────────────────────────────────────────────

function loadConfig() {
    try {
        if (fs.existsSync(CONFIG_PATH)) return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8'));
    } catch (_) {}
    return {};
}

function isEnabled(jid) {
    return loadConfig()?.antiviewonce?.groups?.[jid]?.enabled === true;
}

// ── LOG ───────────────────────────────────────────────────────────────────────

function appendLog(entry) {
    try {
        let data = { terdeteksi: [] };
        if (fs.existsSync(LOG_PATH)) {
            try { data = JSON.parse(fs.readFileSync(LOG_PATH, 'utf-8')); } catch (_) {}
        }
        if (!Array.isArray(data.terdeteksi)) data.terdeteksi = [];
        data.terdeteksi.unshift(entry);
        if (data.terdeteksi.length > 200) data.terdeteksi = data.terdeteksi.slice(0, 200);
        fs.writeFileSync(LOG_PATH, JSON.stringify(data, null, 2), 'utf-8');
    } catch (_) {}
}

// ── UNWRAP VIEW ONCE ──────────────────────────────────────────────────────────

function unwrapViewOnce(rawMsg) {
    if (!rawMsg) return null;

    let msg = rawMsg;
    let isVO = false;

    // Unwrap ephemeral dulu
    if (msg.ephemeralMessage?.message) msg = msg.ephemeralMessage.message;

    // Cek wrapper viewOnce
    if (msg.viewOnceMessage?.message)          { msg = msg.viewOnceMessage.message;          isVO = true; }
    else if (msg.viewOnceMessageV2?.message)   { msg = msg.viewOnceMessageV2.message;        isVO = true; }
    else if (msg.viewOnceMessageV2Extension?.message) { msg = msg.viewOnceMessageV2Extension.message; isVO = true; }

    // Fallback: flag viewOnce langsung di media
    if (!isVO) {
        for (const mt of ['imageMessage', 'videoMessage', 'audioMessage']) {
            if (msg[mt]?.viewOnce === true) { isVO = true; break; }
        }
    }

    if (!isVO) return null;

    const mediaType = getContentType(msg);
    const MEDIA = ['imageMessage', 'videoMessage', 'audioMessage', 'documentMessage'];
    if (!MEDIA.includes(mediaType)) return null;

    return { innerMsg: msg, mediaType, content: msg[mediaType] };
}

// ── FORMAT CAPTION ────────────────────────────────────────────────────────────

const LABEL  = { imageMessage: 'Foto', videoMessage: 'Video', audioMessage: 'Audio', documentMessage: 'Dokumen' };
const SIMBOL = { imageMessage: '🖼', videoMessage: '🎥', audioMessage: '🎵', documentMessage: '📄' };

function buatCaption({ senderName, senderNumber, groupName, isGroup, mediaType }) {
    const tipe = LABEL[mediaType] || 'Media';
    const sym  = SIMBOL[mediaType] || '📨';
    const tgl  = new Date().toLocaleString('id-ID', {
        timeZone: 'Asia/Jakarta', weekday: 'long', day: '2-digit',
        month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false,
    }).replace('.', ':') + ' WIB';
    return (
        `# ◆ ANTI VIEW ONCE — TERDETEKSI\n` +
        `> ◈ _${tgl}_\n\n` +
        `### ${sym} ${tipe} View Once\n` +
        `- *Dari*  : ${senderName} (+${senderNumber})\n` +
        (isGroup ? `- *Grup*  : ${groupName}\n` : `- *Chat*  : Private\n`) +
        `- *Tipe*  : ${tipe}\n\n` +
        `_Pesan sekali lihat berhasil dibuka otomatis_ ◆`
    );
}

// ── MAIN HANDLER ──────────────────────────────────────────────────────────────

export default async function handleAntiViewOnce(message, hisoka) {
    try {
        const from = message?.key?.remoteJid;
        if (!from) return;
        if (message?.key?.fromMe) return;           // skip pesan bot sendiri
        if (!message?.message) return;
        if (!isEnabled(from)) return;               // cek config per grup/chat

        // Unwrap view once
        const vo = unwrapViewOnce(message.message);
        if (!vo) return;                            // bukan view once → skip

        const { innerMsg, mediaType, content } = vo;

        // Download media — ikuti pola antidelete
        let buffer = null;
        try {
            buffer = await downloadMediaMessage(
                { ...message, message: innerMsg },
                'buffer',
                {},
                { logger: hisoka.logger, reuploadRequest: hisoka.updateMediaMessage }
            );
        } catch (dlErr) {
            console.warn('[AntiVO] Download gagal, coba fallback:', dlErr.message);
            try {
                buffer = await downloadMediaMessage(
                    message,
                    'buffer',
                    {},
                    { logger: hisoka.logger, reuploadRequest: hisoka.updateMediaMessage }
                );
            } catch (_) {}
        }

        if (!buffer || buffer.length === 0) {
            console.warn('[AntiVO] Buffer kosong, tidak bisa replay');
            return;
        }

        // Info pengirim
        const participantJid = message.key?.participant || message.participant || from;
        const senderNumber   = participantJid.split('@')[0].split(':')[0];
        const senderName     = message.pushName || senderNumber;
        const isGroup        = isJidGroup(from);
        let groupName        = from;
        if (isGroup) {
            try { groupName = hisoka.groups?.read?.(from)?.subject || hisoka.getName?.(from) || from; } catch (_) {}
        }

        const caption = buatCaption({ senderName, senderNumber, groupName, isGroup, mediaType });

        // Kirim ulang tanpa viewOnce — ikuti pola antidelete sendToTargets
        if (mediaType === 'imageMessage') {
            await hisoka.sendMessage(from, { image: buffer, caption });
        } else if (mediaType === 'videoMessage') {
            await hisoka.sendMessage(from, { video: buffer, caption });
        } else if (mediaType === 'audioMessage') {
            await hisoka.sendMessage(from, { text: caption });
            await hisoka.sendMessage(from, {
                audio   : buffer,
                mimetype: content?.mimetype || 'audio/mp4',
                ptt     : false,
            });
        } else if (mediaType === 'documentMessage') {
            await hisoka.sendMessage(from, {
                document: buffer,
                caption,
                fileName: content?.fileName || 'dokumen',
                mimetype: content?.mimetype || 'application/octet-stream',
            });
        }

        // Log
        appendLog({
            waktu    : new Date().toISOString(),
            sender   : senderNumber,
            nama     : senderName,
            grup     : isGroup ? from : null,
            namaGrup : isGroup ? groupName : null,
            mediaType,
        });

        console.log(`\x1b[36m[AntiVO]\x1b[0m ✅ ${LABEL[mediaType]} dari +${senderNumber} di ${isGroup ? groupName : 'private'} berhasil di-replay`);

    } catch (err) {
        console.error('\x1b[31m[AntiVO] Error:\x1b[39m', err.message);
    }
}
