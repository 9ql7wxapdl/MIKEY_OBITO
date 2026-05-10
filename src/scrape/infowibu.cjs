'use strict';

const axios = require('axios');
const fs    = require('fs');
const path  = require('path');

const DATA_FILE = path.join(process.cwd(), 'data', 'infowibu.json');

const JIKAN_BASE  = 'https://api.jikan.moe/v4';
const ANILIST_URL = 'https://graphql.anilist.co';

const HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'application/json',
};

// ── Data helpers ──────────────────────────────────────────────────────────────

function loadData() {
    try {
        if (fs.existsSync(DATA_FILE)) {
            return JSON.parse(fs.readFileSync(DATA_FILE, 'utf-8'));
        }
    } catch (_) {}
    return { groups: {}, sentIds: [], lastFetch: 0 };
}

function saveData(data) {
    try {
        fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), 'utf-8');
    } catch (_) {}
}

// ── Group settings ────────────────────────────────────────────────────────────

function setGroupEnabled(groupJid, enabled) {
    const data = loadData();
    if (!data.groups) data.groups = {};
    data.groups[groupJid] = { enabled, updatedAt: Date.now() };
    saveData(data);
}

function isGroupEnabled(groupJid) {
    const data = loadData();
    return !!(data.groups?.[groupJid]?.enabled);
}

function getEnabledGroups() {
    const data = loadData();
    return Object.entries(data.groups || {})
        .filter(([, v]) => v.enabled)
        .map(([jid]) => jid);
}

function getAllGroupSettings() {
    return loadData().groups || {};
}

// ── Sent-ID dedup ─────────────────────────────────────────────────────────────

function markSent(id) {
    const data = loadData();
    if (!data.sentIds) data.sentIds = [];
    data.sentIds = [String(id), ...data.sentIds].slice(0, 200);
    saveData(data);
}

function alreadySent(id) {
    const data = loadData();
    return (data.sentIds || []).includes(String(id));
}

// ── Jikan news ────────────────────────────────────────────────────────────────

async function fetchJikanNews() {
    const { data } = await axios.get(`${JIKAN_BASE}/anime/news`, {
        params: { limit: 5 },
        headers: HEADERS,
        timeout: 12000,
    }).catch(() => ({ data: null }));
    return data?.data || [];
}

// ── AniList trending (with cover images) ──────────────────────────────────────

const ANILIST_QUERY = `
query ($page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    media(sort: TRENDING_DESC, type: ANIME, status: RELEASING) {
      id
      title { romaji native english }
      description(asHtml: false)
      episodes
      status
      season
      seasonYear
      averageScore
      popularity
      genres
      coverImage { extraLarge large }
      bannerImage
      siteUrl
      studios(isMain: true) { nodes { name } }
      nextAiringEpisode { episode airingAt }
    }
  }
}`;

async function fetchTrendingAnime(page = 1, perPage = 10) {
    const { data } = await axios.post(
        ANILIST_URL,
        { query: ANILIST_QUERY, variables: { page, perPage } },
        { headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }, timeout: 15000 }
    );
    return data?.data?.Page?.media || [];
}

// ── Fetch one fresh post (not already sent) ───────────────────────────────────

async function fetchFreshPost() {
    const list = await fetchTrendingAnime(1, 20);
    for (const anime of list) {
        const uid = `al-${anime.id}`;
        if (alreadySent(uid)) continue;
        return { source: 'anilist', anime, uid };
    }
    // Fallback: second page
    const list2 = await fetchTrendingAnime(2, 20);
    for (const anime of list2) {
        const uid = `al-${anime.id}`;
        if (alreadySent(uid)) continue;
        return { source: 'anilist', anime, uid };
    }
    return null;
}

// ── Caption formatter ─────────────────────────────────────────────────────────

function formatCaption(post, opts = {}) {
    const { realtime = true } = opts;
    const a = post.anime;

    const title  = a.title?.romaji || a.title?.english || a.title?.native || '?';
    const native = a.title?.native ? ` _(${a.title.native})_` : '';
    const score  = a.averageScore ? `⭐ ${(a.averageScore / 10).toFixed(1)}/10` : '⭐ -';
    const genres = (a.genres || []).slice(0, 4).join(', ') || '-';
    const studio = a.studios?.nodes?.[0]?.name || '-';
    const eps    = a.episodes ? `${a.episodes} eps` : 'Ongoing';

    let desc = (a.description || '')
        .replace(/<[^>]+>/g, '')
        .replace(/\n{3,}/g, '\n\n')
        .trim()
        .slice(0, 200);
    if ((a.description || '').length > 200) desc += '...';

    let nextEp = '';
    if (a.nextAiringEpisode) {
        const epNum = a.nextAiringEpisode.episode;
        const airsAt = new Date(a.nextAiringEpisode.airingAt * 1000);
        const dateStr = airsAt.toLocaleDateString('id-ID', {
            weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
        });
        nextEp = `\n📅 *Ep ${epNum} tayang:* ${dateStr}`;
    }

    const badge = realtime ? '🔴 *REALTIME INFO WIBU*' : '📢 *INFO WIBU*';
    const now   = new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });

    return (
        `${badge}\n` +
        `${'─'.repeat(28)}\n` +
        `🎌 *${title}*${native}\n\n` +
        `📖 ${desc}\n\n` +
        `${score}  |  🎭 ${genres}\n` +
        `🏢 Studio: *${studio}*\n` +
        `📺 Episode: *${eps}*${nextEp}\n\n` +
        `🔗 ${a.siteUrl || 'https://anilist.co'}\n` +
        `${'─'.repeat(28)}\n` +
        `🕐 _${now} WIB_`
    );
}

// ── Image URL helper ──────────────────────────────────────────────────────────

function getCoverUrl(post) {
    const a = post.anime;
    return a.bannerImage || a.coverImage?.extraLarge || a.coverImage?.large || null;
}

// ── Simulate (for testing) ────────────────────────────────────────────────────

async function simulate() {
    const list = await fetchTrendingAnime(1, 5);
    if (!list.length) throw new Error('Tidak ada data dari AniList.');
    const anime = list[0];
    const post  = { source: 'anilist', anime, uid: `al-${anime.id}` };
    return {
        caption  : formatCaption(post, { realtime: true }),
        imageUrl : getCoverUrl(post),
        title    : anime.title?.romaji || anime.title?.english || '?',
        uid      : post.uid,
    };
}

module.exports = {
    loadData,
    saveData,
    setGroupEnabled,
    isGroupEnabled,
    getEnabledGroups,
    getAllGroupSettings,
    markSent,
    alreadySent,
    fetchTrendingAnime,
    fetchFreshPost,
    formatCaption,
    getCoverUrl,
    simulate,
};
