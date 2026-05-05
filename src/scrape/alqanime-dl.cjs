'use strict';

const axios    = require('axios');
const cheerio  = require('cheerio');
const fs       = require('fs');
const path     = require('path');

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

// ─── Ekstrak URL dari shortlink ouo.io ────────────────────────────────────
function resolveOuo(url) {
    try {
        const u = new URL(url);
        const real = u.searchParams.get('s');
        if (real) return decodeURIComponent(real);
    } catch (_) {}
    return url;
}

// ─── PixelDrain: langsung dari API ────────────────────────────────────────
async function resolvePixelDrain(url) {
    const id = url.match(/pixeldrain\.com\/(?:u|l)\/([^/?#]+)/)?.[1];
    if (!id) throw new Error('PixelDrain: ID tidak ditemukan');
    const directUrl = `https://pixeldrain.com/api/file/${id}`;
    const info = await axios.head(directUrl, { headers: { 'User-Agent': UA }, timeout: 10000 });
    const size = parseInt(info.headers['content-length'] || '0');
    const dispName = info.headers['content-disposition']?.match(/filename[^;=\n]*=["']?([^"'\n;]+)/)?.[1]?.trim() || `pixeldrain_${id}.mp4`;
    return { directUrl, fileName: dispName, host: 'PixelDrain', size };
}

// ─── MediaFire: parse halaman HTML ────────────────────────────────────────
async function resolveMediaFire(url) {
    const res = await axios.get(url, {
        headers: { 'User-Agent': UA, 'Accept': 'text/html' },
        timeout: 20000,
    });
    const $ = cheerio.load(res.data);
    const directUrl = $('a[aria-label="Download file"]').attr('href')
                   || $('#downloadButton').attr('href')
                   || $('a.popsok').attr('href');
    if (!directUrl) throw new Error('MediaFire: link download tidak ditemukan di halaman');
    const info = await axios.head(directUrl, { headers: { 'User-Agent': UA }, timeout: 10000 });
    const size = parseInt(info.headers['content-length'] || '0');
    const dispName = info.headers['content-disposition']?.match(/filename[^;=\n]*=["']?([^"'\n;]+)/)?.[1]?.trim()
                  || $('div.filename').text().trim()
                  || 'mediafire_video.mp4';
    return { directUrl, fileName: dispName, host: 'MediaFire', size };
}

// ─── AceFile: AJAX endpoint ───────────────────────────────────────────────
async function resolveAceFile(url) {
    const fileId = url.match(/acefile\.co\/f\/(\d+)/)?.[1];
    if (!fileId) throw new Error('AceFile: ID tidak ditemukan');
    const res = await axios.post(
        'https://acefile.co/ajax.php',
        new URLSearchParams({ ajax: 'download', id: fileId }),
        {
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'X-Requested-With': 'XMLHttpRequest',
                'Referer': url,
                'User-Agent': UA,
            },
            timeout: 15000,
        }
    );
    const directUrl = res.data?.url || res.data?.link || res.data?.download_url;
    if (!directUrl) throw new Error('AceFile: respons API tidak mengandung link download');
    const info = await axios.head(directUrl, { headers: { 'User-Agent': UA }, timeout: 10000 }).catch(() => ({ headers: {} }));
    const size = parseInt(info.headers['content-length'] || '0');
    const dispName = info.headers['content-disposition']?.match(/filename[^;=\n]*=["']?([^"'\n;]+)/)?.[1]?.trim() || `acefile_${fileId}.mp4`;
    return { directUrl, fileName: dispName, host: 'AceFile', size };
}

// ─── Auto-resolve: deteksi host dan resolve ───────────────────────────────
async function resolveDirectLink(rawUrl) {
    let url = rawUrl.trim();

    // Buka ouo.io wrapper dulu
    if (url.includes('ouo.io')) url = resolveOuo(url);

    if (url.includes('pixeldrain.com'))  return await resolvePixelDrain(url);
    if (url.includes('mediafire.com'))   return await resolveMediaFire(url);
    if (url.includes('acefile.co'))      return await resolveAceFile(url);

    if (url.includes('gofile.io')) {
        throw new Error('GoFile butuh akun premium. Pakai link PixelDrain atau MediaFire.');
    }
    if (url.includes('terabox') || url.includes('4shared')) {
        throw new Error('Host ini tidak didukung. Pakai link PixelDrain atau MediaFire.');
    }

    // Fallback: coba HEAD dulu, anggap direct
    const info = await axios.head(url, { headers: { 'User-Agent': UA }, timeout: 10000 }).catch(() => ({ headers: {} }));
    const size = parseInt(info.headers['content-length'] || '0');
    const dispName = info.headers['content-disposition']?.match(/filename[^;=\n]*=["']?([^"'\n;]+)/)?.[1]?.trim() || path.basename(new URL(url).pathname) || 'video.mp4';
    return { directUrl: url, fileName: dispName, host: 'Direct', size };
}

// ─── Format ukuran file ───────────────────────────────────────────────────
function formatSize(bytes) {
    if (!bytes) return '? MB';
    if (bytes < 1024 * 1024)   return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 ** 3)     return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 ** 3).toFixed(2)} GB`;
}

// ─── Stream download ke file tmp dengan progress callback ─────────────────
async function downloadToTmp(directUrl, destPath, onProgress) {
    const res = await axios.get(directUrl, {
        headers: { 'User-Agent': UA },
        responseType: 'stream',
        timeout: 0,
    });

    const total = parseInt(res.headers['content-length'] || '0');
    let downloaded = 0;
    let lastReport = 0;

    return new Promise((resolve, reject) => {
        const writer = fs.createWriteStream(destPath);
        res.data.on('data', chunk => {
            downloaded += chunk.length;
            const now = Date.now();
            if (onProgress && now - lastReport > 3000) {
                lastReport = now;
                const pct = total ? Math.round((downloaded / total) * 100) : 0;
                onProgress(downloaded, total, pct).catch(() => {});
            }
        });
        res.data.pipe(writer);
        writer.on('finish', resolve);
        writer.on('error', reject);
        res.data.on('error', reject);
    });
}

module.exports = { resolveDirectLink, downloadToTmp, formatSize };
