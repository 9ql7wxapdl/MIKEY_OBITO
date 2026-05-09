'use strict';

const axios = require('axios');

const BASE = 'https://cosplaytele.com';
const API  = `${BASE}/wp-json/wp/v2`;

const HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': BASE,
};

const MAX_IMAGES = 30;
const MAX_VIDEOS = 5;

function decodeEntities(str) {
    return String(str || '')
        .replace(/&#8211;/g, '–')
        .replace(/&#8220;/g, '"')
        .replace(/&#8221;/g, '"')
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#\d+;/g, '')
        .replace(/<[^>]+>/g, '')
        .trim();
}

function extractMediaFromContent(html) {
    const seen = new Set();
    const images = [];

    // 1. Ambil dari href='...' (single quote) — full-size originals
    const reSingle = /href='(https:\/\/cosplaytele\.com\/wp-content\/uploads\/[^'>\s]+\.(?:jpg|jpeg|png|webp|gif))'/gi;
    let m;
    while ((m = reSingle.exec(html)) !== null) {
        const url = m[1];
        if (!seen.has(url)) { seen.add(url); images.push(url); }
    }

    // 2. Fallback: ambil dari src="..." (double quote) jika href kosong
    if (images.length === 0) {
        const reDouble = /src="(https:\/\/cosplaytele\.com\/wp-content\/uploads\/[^">\s]+\.(?:jpg|jpeg|png|webp|gif))"/gi;
        while ((m = reDouble.exec(html)) !== null) {
            const url = m[1];
            if (!seen.has(url)) { seen.add(url); images.push(url); }
        }
    }

    // 3. Cossora video embeds (1 embed = semua video di post)
    const cossoraIds = [];
    const reCossora = /cossora\.stream\/embed\/([a-f0-9-]{36})/gi;
    const cossoraSeen = new Set();
    while ((m = reCossora.exec(html)) !== null) {
        if (!cossoraSeen.has(m[1])) {
            cossoraSeen.add(m[1]);
            cossoraIds.push(`https://cossora.stream/embed/${m[1]}`);
        }
    }

    return { images, cossoraIds };
}

function extractThumbnail(post) {
    try {
        const emb = post._embedded?.['wp:featuredmedia'];
        if (emb && emb[0]) {
            const sizes = emb[0]?.media_details?.sizes || {};
            return sizes.medium?.source_url || sizes.thumbnail?.source_url || emb[0].source_url || '';
        }
    } catch (_) {}
    return '';
}

async function cosplayteleSearch(keyword, { page = 1, perPage = 8 } = {}) {
    if (!keyword || !String(keyword).trim()) throw new Error('Keyword tidak boleh kosong.');

    const { data } = await axios.get(`${API}/posts`, {
        params: {
            search: String(keyword).trim(),
            per_page: perPage,
            page,
            _embed: 'wp:featuredmedia',
            _fields: 'id,title,link,date,_embedded',
        },
        headers: HEADERS,
        timeout: 15000,
    });

    if (!Array.isArray(data) || data.length === 0) {
        throw new Error(`Tidak ada hasil untuk "${keyword}". Coba kata kunci lain.`);
    }

    return data.map(post => ({
        id: post.id,
        title: decodeEntities(post.title?.rendered || ''),
        link: post.link || '',
        date: post.date || '',
        thumbnail: extractThumbnail(post),
    }));
}

async function cosplayteleGetPost(postId) {
    const { data } = await axios.get(`${API}/posts/${postId}`, {
        params: { _fields: 'id,title,link,content' },
        headers: HEADERS,
        timeout: 20000,
    });

    const { images, cossoraIds } = extractMediaFromContent(data.content?.rendered || '');

    if (images.length === 0 && cossoraIds.length === 0) {
        throw new Error('Tidak ada media ditemukan di post ini.');
    }

    return {
        id: data.id,
        title: decodeEntities(data.title?.rendered || ''),
        link: data.link || '',
        images: images.slice(0, MAX_IMAGES),
        cossoraIds,
        totalImages: images.length,
        hasVideos: cossoraIds.length > 0,
    };
}

async function downloadBuffer(url) {
    const { data } = await axios.get(url, {
        headers: {
            ...HEADERS,
            Accept: 'image/webp,image/jpeg,image/png,video/mp4,*/*',
            Referer: BASE,
        },
        responseType: 'arraybuffer',
        timeout: 30000,
        maxRedirects: 5,
    });
    return Buffer.from(data);
}

function formatCosplayteleCaption(post, { imgIndex, imgTotal } = {}) {
    const title = post.title || '';
    const link  = post.link  || '';
    const vidHint = post.hasVideos ? ` • ada video` : '';
    return `📸 *${title}*\n` +
           `🖼️ ${imgIndex + 1}/${imgTotal}${vidHint}\n` +
           `🔗 ${link}`;
}

function formatCosplayteleSearchList(results) {
    const lines = results.map((r, i) => {
        const match = r.title.match(/"(\d+ photos?(?:\s*and\s*\d+ videos?)?)/i);
        const count = match ? ` *(${match[1]})* ` : '';
        const cleanTitle = r.title.replace(/"[^"]*"/g, '').replace(/\s{2,}/g, ' ').trim();
        return `${i + 1}. ${cleanTitle}${count}`;
    });
    return lines.join('\n');
}

module.exports = {
    cosplayteleSearch,
    cosplayteleGetPost,
    downloadBuffer,
    formatCosplayteleCaption,
    formatCosplayteleSearchList,
};
