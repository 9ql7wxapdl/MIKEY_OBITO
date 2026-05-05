'use strict';

import path from 'path';
import fs from 'fs';

const DATA_DIR = path.join(process.cwd(), 'data');
const KV_DIR   = path.join(DATA_DIR, 'kv');

if (!fs.existsSync(KV_DIR)) fs.mkdirSync(KV_DIR, { recursive: true });

function kvPath(key) {
    return path.join(KV_DIR, String(key).replace(/[^a-zA-Z0-9_-]/g, '_') + '.json');
}

export function kvGet(key, fallback = null) {
    try {
        const p = kvPath(key);
        if (!fs.existsSync(p)) return fallback;
        return JSON.parse(fs.readFileSync(p, 'utf-8'));
    } catch { return fallback; }
}

export function kvSet(key, value) {
    try {
        fs.writeFileSync(kvPath(key), JSON.stringify(value, null, 2), 'utf-8');
    } catch {}
}

export function kvMigrateFromJSON(key, jsonPath, transform = null) {
    try {
        if (!fs.existsSync(jsonPath)) return;
        const p = kvPath(key);
        if (fs.existsSync(p)) return;
        const raw  = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
        const data = transform ? transform(raw) : raw;
        kvSet(key, data);
        console.log(`\x1b[32m[DataDB]\x1b[39m Migrasi ${path.basename(jsonPath)} → kv/${key}.json`);
    } catch {}
}
