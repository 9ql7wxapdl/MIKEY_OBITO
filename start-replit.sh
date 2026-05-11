#!/usr/bin/env bash
# ─────────────────────────────────────
#  Start script untuk REPLIT
#  Jalankan: bash start-replit.sh
# ─────────────────────────────────────

echo "▶ Wily Bot - Replit Mode"

# Install node_modules jika belum ada
if [ ! -d "node_modules" ]; then
  echo "▶ node_modules tidak ditemukan, install dulu..."
  npm install
fi

# Install PM2 global jika belum ada
if ! command -v pm2 &>/dev/null; then
  echo "▶ PM2 tidak ditemukan, install PM2..."
  npm install pm2 -g
fi

echo "▶ Update PM2..."
pm2 update

echo "▶ Menjalankan bot dengan PM2..."
pm2 delete wily-bot 2>/dev/null || true
pm2 start ecosystem.config.cjs
pm2 save
echo "✅ Bot berjalan! Menampilkan log..."
pm2 logs wily-bot
