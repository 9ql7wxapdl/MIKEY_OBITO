#!/usr/bin/env bash
# ─────────────────────────────────────
#  Start script untuk PTERODACTYL
#  Startup Command di panel: bash start-ptero.sh
#  (Pterodactyl urus sendiri restart-nya,
#   jadi tidak pakai PM2)
# ─────────────────────────────────────

echo "▶ Wily Bot - Pterodactyl Mode"
echo "▶ Memuat dependensi..."

# Install dependensi jika belum ada
if [ ! -d "node_modules" ]; then
  echo "▶ node_modules tidak ditemukan, install dulu..."
  npm install
fi

echo "✅ Menjalankan bot..."
node index.js
