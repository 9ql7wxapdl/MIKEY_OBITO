#!/usr/bin/env bash
# ─────────────────────────────────────
#  Start script untuk PTERODACTYL
#  Startup Command di panel: bash start-ptero.sh
# ─────────────────────────────────────

echo "▶ Wily Bot - Pterodactyl Mode"

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

# ── Auto-restart loop ──
RESTART_COUNT=0
MAX_RESTARTS=10
RESTART_DELAY=5

echo "✅ Menjalankan bot dengan auto-restart..."
while true; do
  node index.js
  EXIT_CODE=$?

  RESTART_COUNT=$((RESTART_COUNT + 1))
  echo "⚠️  Bot berhenti (exit code: $EXIT_CODE), restart ke-$RESTART_COUNT dalam ${RESTART_DELAY}s..."

  if [ "$RESTART_COUNT" -ge "$MAX_RESTARTS" ]; then
    echo "❌ Terlalu banyak restart ($MAX_RESTARTS kali), bot dihentikan."
    exit 1
  fi

  sleep $RESTART_DELAY
  echo "▶ Menjalankan ulang bot..."
done
