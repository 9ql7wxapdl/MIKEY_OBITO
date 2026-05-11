#!/usr/bin/env bash
# ─────────────────────────────────────
#  Start script untuk REPLIT
#  Jalankan: bash start-replit.sh
# ─────────────────────────────────────

echo "▶ Menjalankan Wily Bot dengan PM2..."
pm2 delete wily-bot 2>/dev/null || true
pm2 start ecosystem.config.cjs
pm2 save
echo "✅ Bot berjalan! Menampilkan log..."
pm2 logs wily-bot
