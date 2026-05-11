#!/usr/bin/env bash
# ─────────────────────────────────────
#  Start script untuk PTERODACTYL
#  Startup Command di panel: bash start-ptero.sh
# ─────────────────────────────────────

CONFIG_FILE="./config.json"

# ── Ambil config Telegram dari config.json ──
tg_enabled=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8'));console.log(c.telegram?.enabled||false)}catch(e){console.log(false)}")
tg_token=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8'));console.log(c.telegram?.token||'')}catch(e){console.log('')}")
tg_chat=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8'));console.log(c.telegram?.chatId||'')}catch(e){console.log('')}")

# ── Fungsi kirim notif Telegram ──
send_tg() {
  local msg="$1"
  if [ "$tg_enabled" = "true" ] && [ -n "$tg_token" ] && [ -n "$tg_chat" ]; then
    curl -s -X POST "https://api.telegram.org/bot${tg_token}/sendMessage" \
      -d chat_id="$tg_chat" \
      -d parse_mode="Markdown" \
      --data-urlencode text="$msg" > /dev/null 2>&1
  fi
}

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

send_tg "✅ *Wily Bot - Pterodactyl*
Bot berhasil dijalankan.
🕐 $(date '+%Y-%m-%d %H:%M:%S')"

# ── Auto-restart loop ──
RESTART_COUNT=0
MAX_RESTARTS=10
RESTART_DELAY=5

echo "✅ Menjalankan bot dengan auto-restart..."
while true; do
  node index.js
  EXIT_CODE=$?
  RESTART_COUNT=$((RESTART_COUNT + 1))
  NOW=$(date '+%Y-%m-%d %H:%M:%S')

  echo "⚠️  [$NOW] Bot berhenti (exit code: $EXIT_CODE), restart ke-$RESTART_COUNT dalam ${RESTART_DELAY}s..."

  if [ "$RESTART_COUNT" -ge "$MAX_RESTARTS" ]; then
    echo "❌ Terlalu banyak restart ($MAX_RESTARTS kali), bot dihentikan."
    send_tg "❌ *Wily Bot - Pterodactyl*
Bot dihentikan setelah $MAX_RESTARTS kali crash.
Exit Code terakhir: \`$EXIT_CODE\`
🕐 $NOW"
    exit 1
  fi

  send_tg "⚠️ *Wily Bot - Pterodactyl*
Bot crash (exit code: \`$EXIT_CODE\`), restart ke-$RESTART_COUNT dalam ${RESTART_DELAY}s...
🕐 $NOW"

  sleep $RESTART_DELAY
  echo "▶ Menjalankan ulang bot..."
done
