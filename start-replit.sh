#!/usr/bin/env bash
# ─────────────────────────────────────
#  Start script untuk REPLIT
#  Jalankan: bash start-replit.sh
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

send_tg "✅ *Wily Bot - Replit*
Bot berhasil dijalankan.
🕐 $(date '+%Y-%m-%d %H:%M:%S')"

# ── Auto-restart watchdog ──
RESTART_COUNT=0
MAX_RESTARTS=10
RESTART_DELAY=5

echo "▶ Watchdog aktif — memantau proses PM2..."
while true; do
  sleep 10

  STATUS=$(pm2 jlist 2>/dev/null | node -e "
    let d='';
    process.stdin.on('data',c=>d+=c);
    process.stdin.on('end',()=>{
      try{
        const list=JSON.parse(d);
        const bot=list.find(p=>p.name==='wily-bot');
        console.log(bot?bot.pm2_env?.status||'unknown':'not_found');
      }catch(e){console.log('unknown');}
    });
  " 2>/dev/null)

  if [ "$STATUS" != "online" ]; then
    RESTART_COUNT=$((RESTART_COUNT + 1))
    NOW=$(date '+%Y-%m-%d %H:%M:%S')
    echo "⚠️  [$NOW] Bot tidak online (status: ${STATUS}), restart ke-$RESTART_COUNT..."

    if [ "$RESTART_COUNT" -ge "$MAX_RESTARTS" ]; then
      echo "❌ Terlalu banyak restart ($MAX_RESTARTS kali), watchdog berhenti."
      send_tg "❌ *Wily Bot - Replit*
Watchdog berhenti setelah $MAX_RESTARTS kali restart gagal.
🕐 $NOW"
      break
    fi

    send_tg "⚠️ *Wily Bot - Replit*
Bot mati (status: ${STATUS}), restart ke-$RESTART_COUNT...
🕐 $NOW"

    sleep $RESTART_DELAY
    pm2 delete wily-bot 2>/dev/null || true
    pm2 start ecosystem.config.cjs
    pm2 save

    send_tg "✅ *Wily Bot - Replit*
Bot berhasil di-restart (ke-$RESTART_COUNT).
🕐 $(date '+%Y-%m-%d %H:%M:%S')"
    echo "✅ Bot berhasil di-restart!"
  else
    RESTART_COUNT=0
  fi
done
