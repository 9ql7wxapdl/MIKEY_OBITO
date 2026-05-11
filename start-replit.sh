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
echo "✅ Bot berjalan!"

# ── Auto-restart fallback di luar PM2 ──
# Kalau PM2 tidak bisa restart (misal crash total),
# loop ini yang akan hidupkan ulang botnya
RESTART_COUNT=0
MAX_RESTARTS=10
RESTART_DELAY=5

echo "▶ Watchdog aktif — memantau proses PM2..."
while true; do
  sleep 10

  STATUS=$(pm2 jlist 2>/dev/null | grep -o '"status":"[^"]*"' | grep -o '[^"]*$' | head -1)

  if [ "$STATUS" != "online" ]; then
    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo "⚠️  Bot tidak online (status: ${STATUS:-unknown}), restart ke-$RESTART_COUNT..."

    if [ "$RESTART_COUNT" -ge "$MAX_RESTARTS" ]; then
      echo "❌ Terlalu banyak restart ($MAX_RESTARTS kali), hentikan watchdog."
      break
    fi

    sleep $RESTART_DELAY
    pm2 delete wily-bot 2>/dev/null || true
    pm2 start ecosystem.config.cjs
    pm2 save
    echo "✅ Bot berhasil di-restart!"
  else
    RESTART_COUNT=0
  fi
done
