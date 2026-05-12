'use strict';

const BASE_API = 'https://api.vidssave.com/api/contentsite_api';
const BASE_SSE = 'https://api.vidssave.com/sse/contentsite_api';
const AUTH     = '20250901majwlqo';
const DOMAIN   = 'api-ak.vidssave.com';
const HEADERS  = {
    'Content-Type': 'application/x-www-form-urlencoded',
    'User-Agent'  : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Origin'      : 'https://vidssave.com',
    'Referer'     : 'https://vidssave.com/youtube-video-downloader-3cx',
};

function buildBody(data) {
    const params = { auth: AUTH, domain: DOMAIN, ...data };
    return Object.entries(params)
        .map(([k, v]) => encodeURIComponent(k) + '=' + encodeURIComponent(v))
        .join('&');
}

function buildQuery(data) {
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
    return m + ':' + String(s).padStart(2, '0');
}

async function parseVideo(link) {
    const res = await fetch(BASE_API + '/media/parse', {
        method : 'POST',
        headers: HEADERS,
        body   : buildBody({ origin: 'source', link }),
        signal : AbortSignal.timeout(30000),
    });
    if (!res.ok) throw new Error('HTTP ' + res.status + ' saat parse');
    const json = await res.json();
    if (json.status !== 1) throw new Error('parse error: ' + JSON.stringify(json));
    return json.data;
}

async function requestTask(resourceId) {
    const res = await fetch(BASE_API + '/media/download', {
        method : 'POST',
        headers: HEADERS,
        body   : buildBody({ resource_id: resourceId, no_encrypt: 1 }),
        signal : AbortSignal.timeout(15000),
    });
    if (!res.ok) throw new Error('HTTP ' + res.status + ' saat request task');
    const json = await res.json();
    if (json.status !== 1 || !json.data || !json.data.task_id)
        throw new Error(json.msg || 'Gagal mendapatkan task_id');
    return json.data.task_id;
}

async function pollSse(taskId, timeoutMs) {
    timeoutMs = timeoutMs || 25000;
    const sseUrl = BASE_SSE + '/media/download_query?' +
        buildQuery({ task_id: taskId, download_domain: 'vidssave.com', origin: 'content_site' });

    const res = await fetch(sseUrl, {
        headers: Object.assign({}, HEADERS, { 'Accept': 'text/event-stream', 'Cache-Control': 'no-cache' }),
        signal : AbortSignal.timeout(timeoutMs),
    });
    if (!res.ok) throw new Error('HTTP ' + res.status + ' saat SSE');

    const reader = res.body.getReader();
    const dec    = new TextDecoder();
    let buf      = '';

    while (true) {
        const chunk = await reader.read();
        if (chunk.done) throw new Error('SSE stream ended tanpa download_link');

        buf += dec.decode(chunk.value, { stream: true });
        const lines = buf.split('\n');
        buf = lines.pop() || '';

        for (const line of lines) {
            if (!line.startsWith('data:')) continue;
            try {
                const d = JSON.parse(line.slice(5).trim());
                if (d.status === 'success' && d.download_link) return d.download_link;
                if (d.status === 'failed') throw new Error('Vidssave gagal memproses resource ini');
            } catch (e) {
                if (e.message && e.message.indexOf('Vidssave gagal') >= 0) throw e;
            }
        }
    }
}

async function getCdnUrl(resourceId) {
    try {
        const taskId = await requestTask(resourceId);
        const url    = await pollSse(taskId, 25000);
        return url || null;
    } catch (_) {
        return null;
    }
}

async function vidssave(link) {
    if (!link || typeof link !== 'string') throw new Error('Link tidak boleh kosong');
    const url = link.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://'))
        throw new Error('Link harus dimulai dengan http:// atau https://');

    const data      = await parseVideo(url);
    const resources = Array.isArray(data.resources) ? data.resources : [];
    const candidates = resources.filter(function(r) { return r.resource_id; });

    const cdnUrls = await Promise.all(candidates.map(function(r) {
        return getCdnUrl(r.resource_id);
    }));

    const videos = [];
    const audios = [];
    const images = [];

    candidates.forEach(function(r, i) {
        const cdnUrl = cdnUrls[i];
        if (!cdnUrl) return;
        const item = {
            quality    : r.quality    || '',
            format     : r.format     || '',
            size       : r.size       || 0,
            sizeStr    : fmtSize(r.size),
            resourceId : r.resource_id,
            downloadUrl: cdnUrl,
        };
        if (r.type === 'video')      videos.push(item);
        else if (r.type === 'audio') audios.push(item);
        else if (r.type === 'image') images.push(item);
        else                         videos.push(item);
    });

    return {
        title      : data.title      || '',
        thumbnail  : data.thumbnail  || '',
        duration   : data.duration   || 0,
        durationStr: fmtDuration(data.duration),
        author     : (data.user_item && (data.user_item.nickname || data.user_item.uid)) || '',
        videos,
        audios,
        images,
        raw        : data,
    };
}

async function vidssaveGetUrl(resourceId) {
    if (!resourceId) throw new Error('resourceId diperlukan');
    return await getCdnUrl(resourceId);
}

module.exports = { vidssave, vidssaveGetUrl };
