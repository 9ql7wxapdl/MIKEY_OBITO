'use strict';

const BASE_URL = 'https://api.vidssave.com/api/contentsite_api';
const AUTH     = '20250901majwlqo';
const DOMAIN   = 'api-ak.vidssave.com';
const HEADERS  = {
    'Content-Type': 'application/x-www-form-urlencoded',
    'User-Agent'  : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Origin'      : 'https://vidssave.com',
    'Referer'     : 'https://vidssave.com/',
};

function buildBody(data) {
    const params = { auth: AUTH, domain: DOMAIN, ...data };
    return Object.entries(params)
        .map(([k, v]) => encodeURIComponent(k) + '=' + encodeURIComponent(v))
        .join('&');
}

function fmtSize(bytes) {
    if (!bytes || bytes <= 0) return '?';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function fmtDuration(sec) {
    if (!sec) return '0:00';
    const m = Math.floor(sec / 60);
    const s = Math.floor(sec % 60);
    return `${m}:${String(s).padStart(2, '0')}`;
}

async function parseVideo(link) {
    const body = buildBody({ origin: 'source', link });

    const res = await fetch(`${BASE_URL}/media/parse`, {
        method : 'POST',
        headers: HEADERS,
        body,
        signal : AbortSignal.timeout(30000),
    });

    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    const json = await res.json();
    if (json.status !== 1) {
        const msg = json.msg || json.status_code || 'Gagal memproses link';
        throw new Error(msg);
    }

    return json.data;
}

async function getDownloadUrl(resourceId) {
    const body = buildBody({ request: resourceId, no_encrypt: 1 });

    const res = await fetch(`${BASE_URL}/media/download`, {
        method : 'POST',
        headers: HEADERS,
        body,
        signal : AbortSignal.timeout(20000),
    });

    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const json = await res.json();
    if (json.status !== 1) throw new Error(json.msg || 'Gagal mendapatkan URL download');
    return json.data?.download_url || json.data?.url || null;
}

/**
 * Download video dari berbagai platform via VidsSave
 * @param {string} link  - URL video (YouTube, TikTok, Instagram, Facebook, X, dll)
 * @returns {Promise<Object>} info video + daftar download
 */
async function vidssave(link) {
    if (!link || typeof link !== 'string') throw new Error('Link tidak boleh kosong');

    const url = link.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
        throw new Error('Link harus dimulai dengan http:// atau https://');
    }

    const data = await parseVideo(url);

    const videos  = [];
    const audios  = [];
    const images  = [];

    const resources = Array.isArray(data.resources) ? data.resources : [];

    for (const r of resources) {
        const realUrl = (r.download_url && r.download_url.startsWith('http')) ? r.download_url : null;
        if (!realUrl) continue;

        const item = {
            quality    : r.quality   || '',
            format     : r.format    || '',
            size       : r.size      || 0,
            sizeStr    : fmtSize(r.size),
            resourceId : r.resource_id || '',
            downloadUrl: realUrl,
            downloadMode: r.download_mode || '',
        };

        if (r.type === 'video')       videos.push(item);
        else if (r.type === 'audio')  audios.push(item);
        else if (r.type === 'image')  images.push(item);
        else                          videos.push(item);
    }

    return {
        title    : data.title     || '',
        thumbnail: data.thumbnail || '',
        duration : data.duration  || 0,
        durationStr: fmtDuration(data.duration),
        author   : data.user_item?.nickname || data.user_item?.uid || '',
        videos,
        audios,
        images,
        raw      : data,
    };
}

/**
 * Ambil direct download URL dari resource_id (jika diperlukan)
 * @param {string} resourceId
 */
async function vidssaveGetUrl(resourceId) {
    if (!resourceId) throw new Error('resourceId diperlukan');
    return await getDownloadUrl(resourceId);
}

module.exports = { vidssave, vidssaveGetUrl };
