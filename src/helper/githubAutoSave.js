/**
 * ─────────────────────────────────────────
 *  GitHub Auto-Save Helper
 *  Watches session, creds, and data files
 *  and auto-commits + pushes to GitHub.
 * ─────────────────────────────────────────
 *  Requires: simple-git npm package
 *  Env var : GITHUB_TOKEN
 * ─────────────────────────────────────────
 */

import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';

const _require = createRequire(import.meta.url);

// ─── Constants ───────────────────────────────────────────────────────────────
const DEBOUNCE_MS       = 30_000;   // max 1 commit per 30 seconds
const LOG_PREFIX        = '\x1b[35m[GitAutoSave]\x1b[0m';
const LOG_OK            = '\x1b[32m[GitAutoSave]\x1b[0m';
const LOG_WARN          = '\x1b[33m[GitAutoSave]\x1b[0m';
const LOG_ERR           = '\x1b[31m[GitAutoSave]\x1b[0m';

// ─── State ───────────────────────────────────────────────────────────────────
let git             = null;
let debounceTimer   = null;
let watchers        = [];
let isRunning       = false;
let pendingCommit   = false;
let isCommitting    = false;

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Build the authenticated remote URL from GITHUB_TOKEN.
 * Supports both https://github.com/... and git@github.com:... remotes.
 */
async function buildAuthRemote(token) {
    try {
        const remotes = await git.getRemotes(true);
        const origin  = remotes.find(r => r.name === 'origin');
        if (!origin) return null;

        let url = origin.refs.fetch || origin.refs.push || '';

        // Convert SSH → HTTPS if needed
        if (url.startsWith('git@github.com:')) {
            url = url.replace('git@github.com:', 'https://github.com/');
            if (!url.endsWith('.git')) url += '.git';
        }

        // Inject token into HTTPS URL
        if (url.startsWith('https://github.com/')) {
            return url.replace('https://github.com/', `https://${token}@github.com/`);
        }

        return null;
    } catch {
        return null;
    }
}

/**
 * Perform the actual git add → commit → push cycle.
 * Runs at most once per DEBOUNCE_MS window.
 */
async function doCommitAndPush() {
    if (isCommitting) {
        pendingCommit = true;
        return;
    }

    const token = process.env.GITHUB_TOKEN;
    if (!token) {
        console.warn(`${LOG_WARN} GITHUB_TOKEN tidak ditemukan — auto-save dilewati.`);
        return;
    }

    isCommitting = true;
    try {
        const cwd = process.cwd();

        // Paths to track
        const targets = [
            path.join(cwd, 'sessions', 'hisoka'),
            path.join(cwd, 'creds.json'),
            path.join(cwd, 'data'),
        ];

        // Only add paths that actually exist
        const existing = targets.filter(p => fs.existsSync(p));
        if (!existing.length) {
            console.log(`${LOG_WARN} Tidak ada file target yang ditemukan, skip commit.`);
            return;
        }

        // Stage files
        for (const target of existing) {
            try {
                await git.add(target);
            } catch (addErr) {
                console.error(`${LOG_ERR} Gagal git add "${target}": ${addErr.message}`);
            }
        }

        // Check if there is anything staged
        const status = await git.status();
        const hasChanges =
            status.staged.length > 0 ||
            status.created.length > 0 ||
            status.modified.length > 0 ||
            status.deleted.length > 0;

        if (!hasChanges) {
            // Nothing new to commit
            return;
        }

        // Commit
        const timestamp = new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });
        const commitMsg = `chore: auto-save bot files [${timestamp}]`;

        await git.commit(commitMsg, { '--allow-empty': null });

        // Push with token-authenticated remote
        const authRemote = await buildAuthRemote(token);
        if (!authRemote) {
            console.error(`${LOG_ERR} Tidak bisa membangun URL remote dengan token. Push dibatalkan.`);
            return;
        }

        const branch = (await git.revparse(['--abbrev-ref', 'HEAD'])).trim();
        await git.push(authRemote, branch);

        const fileCount = status.staged.length + status.created.length + status.modified.length + status.deleted.length;
        console.log(`${LOG_OK} ✅ Auto-save berhasil: ${fileCount} file(s) → "${commitMsg}"`);

    } catch (err) {
        // Never crash the bot — just log
        console.error(`${LOG_ERR} Error saat commit/push: ${err.message}`);
    } finally {
        isCommitting = false;

        // If another change arrived while we were committing, run again
        if (pendingCommit) {
            pendingCommit = false;
            scheduleCommit();
        }
    }
}

/**
 * Debounced trigger — resets the 30-second window on every file change.
 */
function scheduleCommit() {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
        debounceTimer = null;
        doCommitAndPush().catch(err => {
            console.error(`${LOG_ERR} Unhandled error in doCommitAndPush: ${err.message}`);
        });
    }, DEBOUNCE_MS);
}

/**
 * Watch a single path (file or directory) with fs.watch.
 * Returns the watcher instance, or null if the path doesn't exist.
 */
function watchPath(targetPath, label) {
    if (!fs.existsSync(targetPath)) {
        console.log(`${LOG_WARN} Path tidak ditemukan, skip watch: ${label}`);
        return null;
    }

    try {
        const watcher = fs.watch(targetPath, { recursive: true }, (eventType, filename) => {
            if (!isRunning) return;
            // Ignore lock files and temp files
            if (filename && (filename.endsWith('.lock') || filename.startsWith('.'))) return;
            console.log(`${LOG_PREFIX} 📝 Perubahan terdeteksi: ${label}/${filename || ''} (${eventType})`);
            scheduleCommit();
        });

        watcher.on('error', err => {
            console.error(`${LOG_ERR} Watcher error pada "${label}": ${err.message}`);
        });

        console.log(`${LOG_OK} 👁  Memantau: ${label}`);
        return watcher;
    } catch (err) {
        console.error(`${LOG_ERR} Gagal memulai watcher untuk "${label}": ${err.message}`);
        return null;
    }
}

// ─── Public API ──────────────────────────────────────────────────────────────

/**
 * Start the GitHub auto-save watcher.
 * Safe to call multiple times — stops any existing instance first.
 */
export async function startGithubAutoSave() {
    if (!process.env.GITHUB_TOKEN) {
        console.warn(`${LOG_WARN} GITHUB_TOKEN tidak diset — GitHub auto-save tidak aktif.`);
        return;
    }

    // Stop any previous instance cleanly
    stopGithubAutoSave();

    try {
        // Lazy-load simple-git (avoids hard crash if package missing)
        const simpleGit = _require('simple-git');
        git = simpleGit.default ? simpleGit.default(process.cwd()) : simpleGit(process.cwd());
    } catch (err) {
        console.error(`${LOG_ERR} Gagal load simple-git: ${err.message}`);
        console.error(`${LOG_ERR} Pastikan "simple-git" sudah diinstall: npm install simple-git`);
        return;
    }

    // Verify this is a git repo
    try {
        const isRepo = await git.checkIsRepo();
        if (!isRepo) {
            console.error(`${LOG_ERR} Direktori ini bukan git repository. Auto-save tidak aktif.`);
            return;
        }
    } catch (err) {
        console.error(`${LOG_ERR} Gagal cek git repo: ${err.message}`);
        return;
    }

    // Configure git identity if not already set (needed for commits in CI/containers)
    try {
        const name  = await git.raw(['config', 'user.name']).catch(() => '');
        const email = await git.raw(['config', 'user.email']).catch(() => '');
        if (!name.trim())  await git.addConfig('user.name',  'WilyBot AutoSave');
        if (!email.trim()) await git.addConfig('user.email', 'wilybot@autosave.local');
    } catch {
        // Non-fatal — git may already have global config
    }

    isRunning = true;

    const cwd = process.cwd();

    // Watch targets
    const watchTargets = [
        { p: path.join(cwd, 'sessions', 'hisoka'), label: 'sessions/hisoka' },
        { p: path.join(cwd, 'creds.json'),          label: 'creds.json'       },
        { p: path.join(cwd, 'data'),                label: 'data'             },
    ];

    for (const { p, label } of watchTargets) {
        const w = watchPath(p, label);
        if (w) watchers.push(w);
    }

    console.log(`${LOG_OK} ✅ GitHub auto-save aktif (debounce: ${DEBOUNCE_MS / 1000}s)`);
}

/**
 * Stop all watchers and cancel any pending commit timer.
 */
export function stopGithubAutoSave() {
    isRunning = false;

    if (debounceTimer) {
        clearTimeout(debounceTimer);
        debounceTimer = null;
    }

    for (const w of watchers) {
        try { w.close(); } catch {}
    }
    watchers = [];

    if (git) {
        git = null;
    }

    console.log(`${LOG_WARN} GitHub auto-save dihentikan.`);
}
