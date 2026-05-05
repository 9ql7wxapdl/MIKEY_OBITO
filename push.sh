#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║                                                          ║
# ║              🚀  PUSH SCRIPT — BANG WILY  🚀             ║
# ║                                                          ║
# ║   Author : Bang Wily (Wilykun1994)                       ║
# ║   Telegram: @Wilykun1994                                 ║
# ║   Versi  : 1.1  •  Auto Commit + Multi-Branch Push       ║
# ║                                                          ║
# ╚══════════════════════════════════════════════════════════╝
#
# 📌 Deskripsi:
#   Script otomatis untuk commit & push ke GitHub.
#   - Pesan commit di-generate otomatis (Conventional Commits)
#   - Menu pemilih branch tujuan (default / pilih / semua)
#   - Setelah sukses, otomatis balik ke menu awal
#
# 📱 Cara pakai (cocok di Termux / mobile shell):
#   bash push.sh                       → tampilkan menu branch
#   bash push.sh "pesan commit kamu"   → pakai pesan custom
#
# 🔐 Keamanan:
#   Token GitHub disimpan di file .token (di-ignore git, aman).
#   Bikin file pertama kali :  echo 'ghp_xxxxxxxx' > .token
#
# ⚙️  Konfigurasi:
#   Edit variabel USER, REPO, DEFAULT_BRANCH di bawah.
#
# ─────────────────────────────────────────────────────────────

USER="hitlabmodv2"
REPO="ReadSwDika_Version"
# DEFAULT_BRANCH di-auto-detect realtime dari GitHub (lihat detect_default_branch).
# Nilai di sini cuma fallback kalau koneksi ke GitHub bermasalah.
DEFAULT_BRANCH="ReadswDika-V15_5"

# Branch yang disembunyikan dari menu (system / internal).
# Pisahkan dengan spasi. Contoh: "replit-agent gh-pages backup"
IGNORE_BRANCHES="replit-agent HEAD"

set -o pipefail
# Catatan: sengaja TIDAK pakai `set -e` biar error per-branch nggak
# langsung kill seluruh script — biar bisa kembali ke menu.

# ===== Warna (opsional, aman di Termux) =====
if [ -t 1 ]; then
  C_RESET="\033[0m"; C_DIM="\033[2m"; C_BOLD="\033[1m"
  C_GREEN="\033[32m"; C_RED="\033[31m"; C_YELLOW="\033[33m"
  C_CYAN="\033[36m"; C_BLUE="\033[34m"; C_MAGENTA="\033[35m"
else
  C_RESET=""; C_DIM=""; C_BOLD=""
  C_GREEN=""; C_RED=""; C_YELLOW=""
  C_CYAN=""; C_BLUE=""; C_MAGENTA=""
fi

CUSTOM_MSG="${1:-}"

# ===== Helper: buka URL di browser (Termux / Linux / macOS) =====
open_url() {
  local url="$1"
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "$url" 2>/dev/null &
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" 2>/dev/null &
  elif command -v open >/dev/null 2>&1; then
    open "$url" 2>/dev/null &
  else
    return 1
  fi
  return 0
}

# ===== Layar generate token otomatis =====
# Buka halaman GitHub pre-filled → scope repo sudah tercentang otomatis.
screen_generate_token() {
  # Semua scope dari GitHub PAT classic — tercentang otomatis saat halaman terbuka
  local _ALL_SCOPES="repo,repo:status,repo_deployment,public_repo,repo:invite,security_events"
  _ALL_SCOPES="${_ALL_SCOPES},workflow"
  _ALL_SCOPES="${_ALL_SCOPES},write:packages,read:packages,delete:packages"
  _ALL_SCOPES="${_ALL_SCOPES},admin:org,write:org,read:org,manage_runners:org"
  _ALL_SCOPES="${_ALL_SCOPES},admin:public_key,write:public_key,read:public_key"
  _ALL_SCOPES="${_ALL_SCOPES},admin:repo_hook,write:repo_hook,read:repo_hook"
  _ALL_SCOPES="${_ALL_SCOPES},admin:org_hook"
  _ALL_SCOPES="${_ALL_SCOPES},gist,notifications"
  _ALL_SCOPES="${_ALL_SCOPES},user,read:user,user:email,user:follow"
  _ALL_SCOPES="${_ALL_SCOPES},delete_repo"
  _ALL_SCOPES="${_ALL_SCOPES},write:discussion,read:discussion"
  _ALL_SCOPES="${_ALL_SCOPES},admin:enterprise,manage_runners:enterprise,manage_billing:enterprise,read:enterprise,scim:enterprise"
  _ALL_SCOPES="${_ALL_SCOPES},audit_log,read:audit_log"
  _ALL_SCOPES="${_ALL_SCOPES},codespace,codespace:secrets"
  _ALL_SCOPES="${_ALL_SCOPES},copilot,manage_billing:copilot"
  _ALL_SCOPES="${_ALL_SCOPES},write:network_configurations,read:network_configurations"
  _ALL_SCOPES="${_ALL_SCOPES},project,read:project"
  _ALL_SCOPES="${_ALL_SCOPES},admin:gpg_key,write:gpg_key,read:gpg_key"
  _ALL_SCOPES="${_ALL_SCOPES},admin:ssh_signing_key,write:ssh_signing_key,read:ssh_signing_key"
  local _BASE_URL="https://github.com/settings/tokens/new?description=BangWilyPushScript&scopes=${_ALL_SCOPES}"

  # ── Pilih Expiration ──
  clear 2>/dev/null || true
  echo -e "${C_BOLD}╔══════════════════════════════════════════════════╗${C_RESET}" >&2
  echo -e "${C_BOLD}║     🔑  GENERATE TOKEN OTOMATIS — BANG WILY      ║${C_RESET}" >&2
  echo -e "${C_BOLD}╚══════════════════════════════════════════════════╝${C_RESET}" >&2
  echo "" >&2
  echo -e "${C_BOLD}Pilih masa berlaku token:${C_RESET}" >&2
  echo "" >&2
  echo -e "  ${C_GREEN}1${C_RESET} No expiration  ${C_DIM}(tidak ada batas waktu — praktis)${C_RESET}" >&2
  echo -e "  ${C_CYAN}2${C_RESET} 1 tahun        ${C_DIM}(365 hari)${C_RESET}" >&2
  echo -e "  ${C_CYAN}3${C_RESET} 90 hari" >&2
  echo -e "  ${C_CYAN}4${C_RESET} 30 hari" >&2
  echo "" >&2
  printf "${C_BOLD}  Pilih [1/2/3/4] ▸ ${C_RESET}" >&2

  local exp_pick="" exp_label="" exp_param=""
  read -r exp_pick </dev/tty
  exp_pick="${exp_pick:-1}"

  # URL dibangun SETELAH pilihan expiration agar parameter &expiration= ikut terkirim ke GitHub
  case "$exp_pick" in
    2) exp_label="1 tahun (365 hari)"; exp_param="365" ;;
    3) exp_label="90 hari";            exp_param="90"  ;;
    4) exp_label="30 hari";            exp_param="30"  ;;
    *) exp_pick="1"; exp_label="No expiration"; exp_param="no_expiry" ;;
  esac

  local TOKEN_URL="${_BASE_URL}&expiration=${exp_param}"

  # ── Buka browser & tampilkan instruksi ──
  clear 2>/dev/null || true
  echo -e "${C_BOLD}╔══════════════════════════════════════════════════╗${C_RESET}" >&2
  echo -e "${C_BOLD}║     🔑  GENERATE TOKEN OTOMATIS — BANG WILY      ║${C_RESET}" >&2
  echo -e "${C_BOLD}╚══════════════════════════════════════════════════╝${C_RESET}" >&2
  echo "" >&2
  echo -e "${C_DIM}  Semua scope sudah tercentang • nama token sudah terisi${C_RESET}" >&2
  echo -e "${C_DIM}  Expiration sudah di-set: ${C_RESET}${C_GREEN}${C_BOLD}${exp_label}${C_RESET}" >&2
  echo "" >&2

  if open_url "$TOKEN_URL"; then
    echo -e "  ${C_GREEN}✅ Browser terbuka!${C_RESET}" >&2
    echo -e "  ${C_DIM}   Kalau tidak terbuka, copy URL di bawah:${C_RESET}" >&2
  else
    echo -e "  ${C_YELLOW}⚠️  Tidak bisa buka browser otomatis.${C_RESET}" >&2
    echo -e "  ${C_DIM}   Copy URL berikut → buka di browser kamu:${C_RESET}" >&2
  fi

  echo "" >&2
  echo -e "  ${C_BLUE}${TOKEN_URL}${C_RESET}" >&2
  echo "" >&2
  echo -e "${C_DIM}─────────────────────────────────────────────────${C_RESET}" >&2
  echo -e "${C_BOLD}Langkah di GitHub:${C_RESET}" >&2
  echo -e "  ${C_CYAN}1.${C_RESET} Pastikan kolom ${C_BOLD}Expiration${C_RESET} sudah menampilkan ${C_GREEN}${C_BOLD}${exp_label}${C_RESET}" >&2
  echo -e "       ${C_YELLOW}(GitHub default 30 hari — cek & ubah kalau perlu!)${C_RESET}" >&2
  echo -e "  ${C_CYAN}2.${C_RESET} Klik ${C_BOLD}Generate token${C_RESET} (tombol hijau, paling bawah)" >&2
  echo -e "  ${C_CYAN}3.${C_RESET} Copy token yang muncul → paste di sini" >&2
  echo "" >&2
  echo -e "${C_DIM}─────────────────────────────────────────────────${C_RESET}" >&2
  printf "${C_BOLD}  Paste token baru ▸ ${C_RESET}" >&2

  local input_tok=""
  read -rs input_tok </dev/tty
  echo "" >&2
  input_tok=$(echo "$input_tok" | tr -d '\n\r ')

  if [ -z "$input_tok" ] || echo "$input_tok" | grep -qE '^(#|ghp_x|TOKEN_KAMU|ISI_TOKEN|CONTOH|<|your)'; then
    echo -e "  ${C_RED}❌ Token kosong atau tidak valid.${C_RESET}" >&2
    sleep 1
    echo ""
    return
  fi

  printf '%s' "$input_tok" > .token.secret
  echo "" >&2
  echo -e "  ${C_GREEN}✅ Token disimpan ke .token.secret${C_RESET}" >&2
  echo -e "  ${C_DIM}   File ini gitignored — aman, tidak ke-upload ke GitHub${C_RESET}" >&2
  echo "" >&2
  sleep 1
  echo "$input_tok"
}

# ===== Layar input token manual =====
screen_manual_token() {
  clear 2>/dev/null || true
  echo -e "${C_BOLD}╔══════════════════════════════════════════════════╗${C_RESET}" >&2
  echo -e "${C_BOLD}║        🔐  INPUT TOKEN MANUAL — BANG WILY        ║${C_RESET}" >&2
  echo -e "${C_BOLD}╚══════════════════════════════════════════════════╝${C_RESET}" >&2
  echo "" >&2
  echo -e "${C_DIM}  Pastikan token punya scope: ${C_BOLD}repo${C_RESET}${C_DIM} (full control)${C_RESET}" >&2
  echo "" >&2
  echo -e "${C_DIM}─────────────────────────────────────────────────${C_RESET}" >&2
  printf "${C_BOLD}  Paste token kamu ▸ ${C_RESET}" >&2

  local input_tok=""
  read -rs input_tok </dev/tty
  echo "" >&2
  input_tok=$(echo "$input_tok" | tr -d '\n\r ')

  if [ -z "$input_tok" ] || echo "$input_tok" | grep -qE '^(#|ghp_x|TOKEN_KAMU|ISI_TOKEN|CONTOH|<|your)'; then
    echo -e "  ${C_RED}❌ Token kosong atau tidak valid.${C_RESET}" >&2
    sleep 1
    echo ""
    return
  fi

  printf '%s' "$input_tok" > .token.secret
  echo "" >&2
  echo -e "  ${C_GREEN}✅ Token disimpan ke .token.secret${C_RESET}" >&2
  echo -e "  ${C_DIM}   File ini gitignored — aman, tidak ke-upload ke GitHub${C_RESET}" >&2
  echo "" >&2
  sleep 1
  echo "$input_tok"
}

# ===== Baca token =====
# Urutan prioritas:
#   1. .token.secret  → file token asli (GITIGNORED, aman)
#   2. Belum ada / tidak valid → langsung minta paste token
setup_token() {
  local tok=""

  # Coba baca dari .token.secret
  if [ -f .token.secret ]; then
    tok=$(tr -d '\n\r ' < .token.secret)
  fi

  # Kalau masih kosong atau placeholder, langsung minta input token
  # Catatan: ghp_x SENGAJA tidak dimasukkan — token valid bisa berawalan ghp_x
  while [ -z "$tok" ] || echo "$tok" | grep -qE '^(#|TOKEN_KAMU|ISI_TOKEN|CONTOH|<|your_)'; do
    clear 2>/dev/null || true
    echo -e "${C_BOLD}╔══════════════════════════════════════════════════╗${C_RESET}" >&2
    echo -e "${C_BOLD}║        🔐  TOKEN GITHUB — BANG WILY              ║${C_RESET}" >&2
    echo -e "${C_BOLD}╚══════════════════════════════════════════════════╝${C_RESET}" >&2
    echo "" >&2
    if [ ! -f .token.secret ]; then
      echo -e "  ${C_YELLOW}⚠️  File .token.secret belum ada.${C_RESET}" >&2
    else
      echo -e "  ${C_YELLOW}⚠️  Token tidak valid / placeholder.${C_RESET}" >&2
    fi
    echo "" >&2
    echo -e "  ${C_BOLD}Cara buat token baru:${C_RESET}" >&2
    echo "" >&2
    echo -e "  ${C_CYAN}[A] Classic Token${C_RESET} ${C_DIM}(recommended — token berawalan ghp_...)${C_RESET}" >&2
    echo -e "      ${C_BLUE}https://github.com/settings/tokens/new${C_RESET}" >&2
    echo -e "      ${C_DIM}→ Centang scope: ${C_RESET}${C_BOLD}repo${C_RESET} ${C_DIM}(baris paling atas, full control)${C_RESET}" >&2
    echo -e "      ${C_DIM}→ Scope lain TIDAK perlu dicentang${C_RESET}" >&2
    echo "" >&2
    echo -e "  ${C_CYAN}[B] Fine-grained Token${C_RESET} ${C_DIM}(token berawalan github_pat_...)${C_RESET}" >&2
    echo -e "      ${C_BLUE}https://github.com/settings/personal-access-tokens/new${C_RESET}" >&2
    echo -e "      ${C_DIM}→ Repository access: ${C_RESET}${C_BOLD}All repositories${C_RESET}" >&2
    echo -e "      ${C_DIM}→ Permissions → Contents: ${C_RESET}${C_BOLD}Read and write${C_RESET}" >&2
    echo "" >&2
    echo -e "  ${C_DIM}💡 Expiration: bebas pilih manual — disarankan ${C_RESET}${C_BOLD}No expiration${C_RESET}${C_DIM} biar tidak perlu buat ulang${C_RESET}" >&2
    echo "" >&2
    echo -e "${C_DIM}  ─────────────────────────────────────────────────${C_RESET}" >&2
    printf "  ${C_BOLD}Paste token ▸ ${C_RESET}" >&2

    local input_tok=""
    read -rs input_tok </dev/tty
    echo "" >&2
    input_tok=$(echo "$input_tok" | tr -d '\n\r ')

    if [ -z "$input_tok" ] || echo "$input_tok" | grep -qE '^(#|TOKEN_KAMU|ISI_TOKEN|CONTOH|<|your_)'; then
      echo -e "  ${C_RED}❌ Token kosong atau tidak valid. Coba lagi.${C_RESET}" >&2
      sleep 1
      tok=""
      continue
    fi

    printf '%s' "$input_tok" > .token.secret
    echo -e "  ${C_GREEN}✅ Token disimpan ke .token.secret${C_RESET}" >&2
    echo -e "  ${C_DIM}   File ini gitignored — aman, tidak ke-upload ke GitHub${C_RESET}" >&2
    echo "" >&2
    sleep 1
    tok="$input_tok"
  done

  echo "$tok"
}

# ===== Hitung sisa hari dari tanggal expiry token =====
# $1 = string tanggal dari header GitHub-Authentication-Token-Expiration
#      contoh format: "2026-05-31 00:00:00 UTC"
# Output: angka sisa hari (bisa 0 atau negatif jika sudah lewat)
_token_days_left() {
  local exp_str="$1"
  # Ambil bagian tanggal saja (YYYY-MM-DD)
  local exp_date
  exp_date=$(echo "$exp_str" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  [ -z "$exp_date" ] && echo "?" && return

  local exp_epoch now_epoch
  exp_epoch=$(date -d "$exp_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$exp_date" +%s 2>/dev/null)
  now_epoch=$(date +%s)

  [ -z "$exp_epoch" ] && echo "?" && return
  echo $(( (exp_epoch - now_epoch) / 86400 ))
}

# ===== Tampilkan status masa berlaku token =====
# $1 = nilai header GitHub-Authentication-Token-Expiration (kosong = no expiry)
_print_token_expiry() {
  local exp_str="$1"

  if [ -z "$exp_str" ]; then
    echo -e "  ${C_GREEN}♾️  Masa berlaku: ${C_BOLD}No expiration${C_RESET}${C_GREEN} — token tidak akan expired${C_RESET}" >&2
    return
  fi

  local days_left
  days_left=$(_token_days_left "$exp_str")

  if [ "$days_left" = "?" ]; then
    echo -e "  ${C_DIM}  Masa berlaku: ${exp_str} (gagal parse tanggal)${C_RESET}" >&2
    return
  fi

  if [ "$days_left" -lt 0 ]; then
    echo -e "  ${C_RED}💀 Token SUDAH EXPIRED sejak ${exp_str}!${C_RESET}" >&2
  elif [ "$days_left" -eq 0 ]; then
    echo -e "  ${C_RED}🚨 Token EXPIRES HARI INI! Segera generate token baru.${C_RESET}" >&2
  elif [ "$days_left" -le 3 ]; then
    echo -e "  ${C_RED}🔴 Token expires dalam ${C_BOLD}${days_left} hari${C_RESET}${C_RED} (${exp_str}) — SEGERA perbarui!${C_RESET}" >&2
  elif [ "$days_left" -le 7 ]; then
    echo -e "  ${C_YELLOW}🟡 Token expires dalam ${C_BOLD}${days_left} hari${C_RESET}${C_YELLOW} (${exp_str}) — segera perbarui.${C_RESET}" >&2
  elif [ "$days_left" -le 30 ]; then
    echo -e "  ${C_YELLOW}🟠 Token expires dalam ${C_BOLD}${days_left} hari${C_RESET}${C_YELLOW} (${exp_str}).${C_RESET}" >&2
  else
    echo -e "  ${C_GREEN}✅ Masa berlaku: ${C_BOLD}${days_left} hari lagi${C_RESET}${C_GREEN} (${exp_str})${C_RESET}" >&2
  fi
}

# ===== Validasi token ke GitHub API secara real-time =====
# Cek apakah token benar-benar valid/aktif sebelum lanjut.
# Sekaligus cek & tampilkan masa berlaku token dari response header.
# Return 0 = valid, 1 = invalid/expired, 2 = tidak bisa cek (network error)
validate_token() {
  local tok="$1"
  local http_code login expiry_header

  echo -e "${C_DIM}  🔄 Memvalidasi token ke GitHub...${C_RESET}" >&2

  # Simpan headers ke file terpisah agar bisa baca GitHub-Authentication-Token-Expiration
  http_code=$(curl -s \
    -o /tmp/_gh_validate.json \
    -D /tmp/_gh_validate_headers.txt \
    -w "%{http_code}" \
    -H "Authorization: token ${tok}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/user" 2>/dev/null)

  case "$http_code" in
    200)
      login=$(grep -o '"login":"[^"]*"' /tmp/_gh_validate.json 2>/dev/null | head -1 | sed 's/"login":"//;s/"//')
      # Baca header masa berlaku token (kosong = no expiry)
      expiry_header=$(grep -i '^github-authentication-token-expiration:' /tmp/_gh_validate_headers.txt 2>/dev/null \
                      | sed 's/^[^:]*: *//;s/\r//' | head -1)
      echo -e "  ${C_GREEN}✅ Token valid!${C_RESET} Login sebagai: ${C_BOLD}${login}${C_RESET}" >&2
      _print_token_expiry "$expiry_header"
      rm -f /tmp/_gh_validate.json /tmp/_gh_validate_headers.txt
      return 0
      ;;
    401)
      rm -f /tmp/_gh_validate.json /tmp/_gh_validate_headers.txt
      echo "" >&2
      echo -e "  ${C_RED}❌ Token ditolak GitHub (HTTP 401).${C_RESET}" >&2
      echo -e "  ${C_YELLOW}   Token baru kadang butuh beberapa detik untuk aktif.${C_RESET}" >&2
      echo "" >&2
      printf "  ${C_BOLD}Tekan Enter untuk coba lagi, atau ketik 'baru' untuk ganti token ▸ ${C_RESET}" >&2
      local _retry_pick=""
      read -r _retry_pick </dev/tty
      _retry_pick=$(echo "$_retry_pick" | tr -d '\n\r ' | tr '[:upper:]' '[:lower:]')
      if [ "$_retry_pick" = "baru" ]; then
        rm -f .token.secret 2>/dev/null
        return 1
      fi
      # Coba lagi dengan token yang sama (jangan hapus file)
      return 1
      ;;
    403)
      rm -f /tmp/_gh_validate.json /tmp/_gh_validate_headers.txt
      echo "" >&2
      echo -e "  ${C_RED}❌ Token ditolak — permission kurang (HTTP 403).${C_RESET}" >&2
      echo -e "  ${C_DIM}   Pastikan scope ${C_BOLD}repo${C_RESET}${C_DIM} (full control) dicentang saat buat token.${C_RESET}" >&2
      echo "" >&2
      printf "  ${C_BOLD}Tekan Enter untuk coba lagi, atau ketik 'baru' untuk ganti token ▸ ${C_RESET}" >&2
      local _retry_pick403=""
      read -r _retry_pick403 </dev/tty
      _retry_pick403=$(echo "$_retry_pick403" | tr -d '\n\r ' | tr '[:upper:]' '[:lower:]')
      if [ "$_retry_pick403" = "baru" ]; then
        rm -f .token.secret 2>/dev/null
      fi
      return 1
      ;;
    ""|000)
      echo -e "  ${C_YELLOW}⚠️  Tidak bisa cek token (tidak ada koneksi internet / GitHub down).${C_RESET}" >&2
      echo -e "  ${C_DIM}   Lanjut tanpa validasi...${C_RESET}" >&2
      rm -f /tmp/_gh_validate.json /tmp/_gh_validate_headers.txt
      return 2
      ;;
    *)
      echo -e "  ${C_YELLOW}⚠️  Respon GitHub tidak terduga (HTTP ${http_code}), lanjut...${C_RESET}" >&2
      rm -f /tmp/_gh_validate.json /tmp/_gh_validate_headers.txt
      return 2
      ;;
  esac
}

TOKEN=$(setup_token)

# Validasi token ke GitHub secara real-time
# Kalau invalid/expired → .token.secret dihapus oleh validate_token,
# lalu setup_token dipanggil lagi → langsung minta paste token baru
while true; do
  validate_result=0
  validate_token "$TOKEN" || validate_result=$?

  if [ "$validate_result" -eq 0 ] || [ "$validate_result" -eq 2 ]; then
    break
  fi

  # validate_result=1 → token invalid, .token.secret sudah dihapus
  # Langsung panggil setup_token lagi — akan minta paste token baru
  TOKEN=$(setup_token)
done

REMOTE_URL="https://${USER}:${TOKEN}@github.com/${USER}/${REPO}.git"

# ===== Setup git =====
[ -d .git ] || git init -q
git config user.name "$USER"
git config user.email "${USER}@users.noreply.github.com"

# Kalau ada >1 remote yang punya branch dengan nama sama (mis. 'main' di
# origin DAN di gitsafe-backup), git checkout jadi ambigu. Setting ini
# bilang "selalu prefer origin" → fix "matched multiple remote tracking branches".
git config checkout.defaultRemote origin

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE_URL"
else
  git remote add origin "$REMOTE_URL"
fi

# ===== Auto-detect default branch dari GitHub (REAL-TIME) =====
# GitHub bisa ganti default branch kapan aja. Daripada hardcode 'main',
# tanyain langsung ke remote: HEAD-nya nunjuk ke branch mana sekarang?
detect_default_branch() {
  local detected
  detected=$(git ls-remote --symref origin HEAD 2>/dev/null \
             | awk '/^ref:/{print $2; exit}' \
             | sed 's|^refs/heads/||')

  if [ -n "$detected" ]; then
    if [ "$detected" != "$DEFAULT_BRANCH" ]; then
      echo -e "${C_DIM}🔄 Default branch di GitHub berubah: ${C_YELLOW}${DEFAULT_BRANCH}${C_RESET}${C_DIM} → ${C_GREEN}${detected}${C_RESET}" >&2
    fi
    DEFAULT_BRANCH="$detected"
  else
    echo -e "${C_DIM}⚠️  Gagal deteksi default branch dari GitHub, pakai fallback: ${DEFAULT_BRANCH}${C_RESET}" >&2
  fi
}
detect_default_branch

# ===== Auto-classify commit (Conventional Commits) =====
classify_commit() {
  local files status_lines
  status_lines=$(git diff --cached --name-status)
  files=$(echo "$status_lines" | awk '{print $2}')

  local added modified deleted
  added=$(echo "$status_lines"   | awk '$1=="A"' | wc -l | tr -d ' ')
  modified=$(echo "$status_lines" | awk '$1=="M"' | wc -l | tr -d ' ')
  deleted=$(echo "$status_lines"  | awk '$1=="D"' | wc -l | tr -d ' ')

  local scope="" scope_count=0
  declare -A scope_map=(
    [src/scrape/]="scrape"
    [src/handler/]="handler"
    [src/helper/]="helper"
    [src/db/]="db"
    [src/lib/]="lib"
    [data/]="data"
    [sessions/]="session"
    [attached_assets/]="assets"
    [.agents/]="agents"
    [jadibot/]="jadibot"
  )

  for prefix in "${!scope_map[@]}"; do
    local cnt
    cnt=$(echo "$files" | grep -c "^${prefix}" || true)
    if [ "$cnt" -gt "$scope_count" ]; then
      scope_count=$cnt
      scope="${scope_map[$prefix]}"
    fi
  done

  if echo "$files" | grep -qE '^(package\.json|package-lock\.json)$'; then
    [ -z "$scope" ] && scope="deps"
  fi
  if echo "$files" | grep -qE '^(\.gitignore|push\.sh|index\.js|config\.json|Dockerfile|fly\.toml|\.npmrc)$'; then
    [ -z "$scope" ] && scope="config"
  fi

  local type=""
  if echo "$files" | grep -qE '^(package\.json|package-lock\.json)$' && [ "$scope_count" -le 1 ]; then
    type="deps"
  elif [ "$added" -ge "$modified" ] && [ "$added" -gt 0 ] && \
       echo "$files" | grep -qE '^src/(scrape|handler|helper|lib)/'; then
    type="feat"
  elif [ "$scope" = "data" ] || [ "$scope" = "session" ]; then
    type="chore"
  elif [ "$scope" = "config" ]; then
    type="chore"
  elif [ "$scope" = "assets" ] || [ "$scope" = "agents" ]; then
    type="chore"
  elif [ "$modified" -gt 0 ] && echo "$files" | grep -qE '^src/'; then
    type="fix"
  else
    type="chore"
  fi

  local sample summary total
  total=$(echo "$files" | wc -l | tr -d ' ')
  sample=$(echo "$files" | head -3 | xargs -n1 basename 2>/dev/null | tr '\n' ', ' | sed 's/, $//')

  if [ "$total" -le 3 ]; then
    summary="$sample"
  else
    summary="$sample +$((total - 3)) file lain"
  fi

  if [ -n "$scope" ]; then
    echo "${type}(${scope}): ${summary}"
  else
    echo "${type}: ${summary}"
  fi
}

# ===== Bersihkan stale index.lock (sisa run sebelumnya yang ke-interrupt) =====
cleanup_stale_lock() {
  local lock=".git/index.lock"
  [ -f "$lock" ] || return 0

  # Kalau lock lebih tua dari 30 detik → anggap stale, hapus.
  local lock_age now mtime
  now=$(date +%s)
  mtime=$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null || echo "$now")
  lock_age=$((now - mtime))

  if [ "$lock_age" -gt 30 ]; then
    rm -f "$lock"
    echo -e "  ${C_DIM}🧹 stale index.lock dihapus (umur ${lock_age}s)${C_RESET}"
  fi
}

# ===== Scan working tree & index secara real-time =====
# Output: kode_status<TAB>path  (pakai porcelain v1 biar stabil di semua versi git)
scan_changes() {
  git status --porcelain --untracked-files=all 2>/dev/null
}

# ===== Scan file yang di-IGNORE .gitignore tapi baru dimodifikasi =====
# Berguna buat ngingetin user "eh, ada file baru di folder data/ tapi
# di-skip karena .gitignore — niat upload nggak?".
# Set var global: IGN_LIST IGN_TOTAL
scan_ignored_recent() {
  IGN_LIST=""; IGN_TOTAL=0
  # Folder yang sering jadi target user pengen upload tapi ke-ignore
  local watch_paths=("data" "jadibot" "sessions/hisoka" "src" ".agents" "attached_assets")

  local now mtime ageS rel
  now=$(date +%s)

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo "$now")
    ageS=$((now - mtime))
    # Cuma yang dimodifikasi dalam 24 jam terakhir
    if [ "$ageS" -le 86400 ]; then
      rel="${f#./}"
      IGN_LIST="${IGN_LIST}${ageS}|${rel}"$'\n'
      IGN_TOTAL=$((IGN_TOTAL + 1))
    fi
  done < <(git ls-files --others --ignored --exclude-standard "${watch_paths[@]}" 2>/dev/null)
}

# ===== Tampilkan ringkas file ignored yang baru diubah =====
print_ignored_preview() {
  [ "$IGN_TOTAL" -eq 0 ] && return 0
  echo -e "  ${C_YELLOW}⚠️  ${IGN_TOTAL} file di-skip oleh .gitignore tapi baru diubah:${C_RESET}"
  local shown=0
  # Sort by ageS asc (paling baru dulu)
  while IFS='|' read -r ageS path; do
    [ -z "$path" ] && continue
    local human
    if [ "$ageS" -lt 60 ]; then human="${ageS}d lalu"
    elif [ "$ageS" -lt 3600 ]; then human="$((ageS / 60))m lalu"
    elif [ "$ageS" -lt 86400 ]; then human="$((ageS / 3600))j lalu"
    else human="$((ageS / 86400))h lalu"
    fi
    if [ "$shown" -lt 6 ]; then
      echo -e "    ${C_DIM}🚫${C_RESET} ${path} ${C_DIM}(${human})${C_RESET}"
      shown=$((shown + 1))
    fi
  done < <(echo "$IGN_LIST" | sort -n)
  if [ "$IGN_TOTAL" -gt 6 ]; then
    echo -e "    ${C_DIM}… +$((IGN_TOTAL - 6)) file lain${C_RESET}"
  fi
  echo -e "  ${C_DIM}   Mau ikut upload? Edit .gitignore atau tambah ke force-add di prepare_stage().${C_RESET}"
}

# ===== Hitung breakdown perubahan dari hasil scan =====
# $1 = output scan_changes
# Set var global: CH_NEW CH_MOD CH_DEL CH_REN CH_TOTAL CH_LIST
count_changes() {
  local raw="$1"
  CH_NEW=0; CH_MOD=0; CH_DEL=0; CH_REN=0; CH_TOTAL=0; CH_LIST=""

  [ -z "$raw" ] && return 0

  # Format porcelain v1: "XY path"  (X=index, Y=worktree). Untuk untracked: "?? path".
  # Kita gabungkan: kalau X atau Y = A/?, hitung baru. M=mod, D=del, R=rename.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local code="${line:0:2}"
    local path="${line:3}"
    local x="${code:0:1}"
    local y="${code:1:1}"

    case "$code" in
      "??") CH_NEW=$((CH_NEW + 1)) ;;
      *)
        case "$x$y" in
          A*|*A) CH_NEW=$((CH_NEW + 1)) ;;
          R*|*R) CH_REN=$((CH_REN + 1)) ;;
          D*|*D) CH_DEL=$((CH_DEL + 1)) ;;
          M*|*M) CH_MOD=$((CH_MOD + 1)) ;;
        esac
        ;;
    esac
    CH_TOTAL=$((CH_TOTAL + 1))
    CH_LIST="${CH_LIST}${code}|${path}"$'\n'
  done <<< "$raw"
}

# ===== Tampilkan ringkas perubahan ke user (max 8 baris) =====
print_changes_preview() {
  [ -z "$CH_LIST" ] && return 0
  echo -e "  ${C_DIM}── perubahan terdeteksi ──${C_RESET}"
  local shown=0
  while IFS='|' read -r code path; do
    [ -z "$path" ] && continue
    local icon
    case "$code" in
      "??"|"A "|" A"|"AM") icon="${C_GREEN}➕${C_RESET}" ;;
      "D "|" D"|"AD")      icon="${C_RED}❌${C_RESET}" ;;
      "R "|" R"|"RM")      icon="${C_CYAN}⚙️ ${C_RESET}" ;;
      "M "|" M"|"MM")      icon="${C_YELLOW}✏️ ${C_RESET}" ;;
      *)                    icon="${C_DIM}•${C_RESET}" ;;
    esac
    if [ "$shown" -lt 8 ]; then
      echo -e "    ${icon} ${path}"
      shown=$((shown + 1))
    fi
  done <<< "$CH_LIST"
  if [ "$CH_TOTAL" -gt 8 ]; then
    echo -e "    ${C_DIM}… +$((CH_TOTAL - 8)) file lain${C_RESET}"
  fi
}

# ===== Stage perubahan & deteksi =====
# Return 0 kalau berhasil, 1 kalau ada error fatal saat staging.
prepare_stage() {
  cleanup_stale_lock

  local err_log
  err_log=$(mktemp)

  # Hapus file sesi lama dari git (yang sekarang di-ignore) — recursive.
  # Pakai ls-files tanpa pola → list semua tracked, lalu filter.
  git ls-files 2>/dev/null | grep -E '^sessions/hisoka/' | while read -r f; do
    case "$f" in
      sessions/hisoka/creds.json|sessions/hisoka/contacts.json|sessions/hisoka/groups.json) ;;
      *) git rm --cached -q "$f" 2>>"$err_log" || true ;;
    esac
  done

  # Auto-untrack node_modules dari git index (file di disk tetap aman).
  local nm_tracked
  nm_tracked=$(git ls-files node_modules 2>/dev/null | wc -l | tr -d ' ')
  if [ "$nm_tracked" -gt 0 ]; then
    echo -e "  ${C_YELLOW}🧹 Untrack node_modules dari git (${nm_tracked} file)...${C_RESET}"
    git rm -r --cached -q node_modules 2>>"$err_log" || true
    echo -e "  ${C_DIM}   (file di disk tetap ada, cuma dilepas dari tracking git)${C_RESET}"
  fi

  # ⚠️  KEAMANAN: Auto-untrack .token.secret agar token asli tidak pernah ke-commit.
  if git ls-files --error-unmatch .token.secret >/dev/null 2>&1; then
    echo -e "  ${C_YELLOW}🔐 Untrack .token.secret dari git (file tetap aman di disk)...${C_RESET}"
    git rm --cached -q .token.secret 2>>"$err_log" || true
  fi

  # Stage SEMUA perubahan (baru, modified, deleted, rename).
  if ! git add -A 2>>"$err_log"; then
    echo -e "  ${C_RED}❌ git add -A gagal${C_RESET}"
    sed 's/^/    /' "$err_log" | tail -10
    rm -f "$err_log"
    return 1
  fi

  # Pastikan .token.secret TIDAK pernah masuk stage — blokir paksa setelah git add -A.
  git rm --cached -q .token.secret 2>/dev/null || true

  # Force-add file penting yang biasanya di-ignore.
  # CATATAN: node_modules & .token.secret SENGAJA TIDAK di-force-add.
  for forced in package-lock.json .env \
                sessions/hisoka/creds.json \
                sessions/hisoka/contacts.json \
                sessions/hisoka/groups.json \
                attached_assets .agents \
                jadibot \
                .replit; do
    [ -e "$forced" ] || continue
    git add -f "$forced" 2>>"$err_log" || true
  done

  # Kalau ada error non-fatal, tampilkan singkat (tapi jangan stop).
  if [ -s "$err_log" ]; then
    local err_count
    err_count=$(wc -l < "$err_log" | tr -d ' ')
    echo -e "  ${C_DIM}⚠️  ${err_count} warning saat staging (diabaikan)${C_RESET}"
  fi

  rm -f "$err_log"
  return 0
}

# ===== Ambil daftar branch via GitHub API (real-time, paginasi otomatis) =====
# Output: satu nama branch per baris, sudah di-sort & deduplikasi.
# Fallback ke git ls-remote kalau API gagal.
fetch_branches() {
  # Bangun pola ignore (regex) dari IGNORE_BRANCHES
  local ignore_pattern=""
  for b in $IGNORE_BRANCHES; do
    [ -z "$ignore_pattern" ] && ignore_pattern="^${b}$" || ignore_pattern="${ignore_pattern}|^${b}$"
  done
  [ -z "$ignore_pattern" ] && ignore_pattern="^$"

  local api_branches=""
  local page=1
  local per_page=100
  local api_ok=0

  # ── GitHub API: ambil semua branch (paginasi) ──
  while true; do
    local chunk
    chunk=$(curl -s \
      -H "Authorization: token ${TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/${USER}/${REPO}/branches?per_page=${per_page}&page=${page}" \
      2>/dev/null)

    # Cek apakah response valid (array JSON, ada field "name")
    if echo "$chunk" | grep -q '"name"'; then
      api_ok=1
      local names
      # Format GitHub API: "name": "branch-name" (ada spasi setelah titik dua)
      names=$(echo "$chunk" | grep -o '"name": *"[^"]*"' | sed 's/"name": *"//;s/"$//')
      api_branches="${api_branches}${names}"$'\n'

      # Kalau hasil < per_page, berarti halaman terakhir
      local count
      count=$(echo "$chunk" | grep -c '"name":' 2>/dev/null || echo "0")
      [ "$count" -lt "$per_page" ] && break
      page=$((page + 1))
    else
      break
    fi
  done

  {
    if [ "$api_ok" -eq 1 ]; then
      # Pakai hasil API — sudah real-time dari GitHub
      echo "$api_branches"
    else
      # Fallback: branch lokal + git ls-remote dengan URL bertoken
      git for-each-ref --format='%(refname)' refs/heads/ 2>/dev/null \
        | sed 's|^refs/heads/||'
      git ls-remote --heads "${REMOTE_URL:-origin}" 2>/dev/null \
        | awk '{print $2}' | sed 's|^refs/heads/||'
    fi
  } \
    | grep -v '^$' \
    | grep -Ev "$ignore_pattern" \
    | sort -u
}

# ===== Header banner =====
banner() {
  clear 2>/dev/null || true
  echo -e "${C_BOLD}🚀 PUSH SCRIPT — BANG WILY${C_RESET}"
  echo -e "${C_DIM}Auto Commit • Multi-Branch • Mobile Friendly${C_RESET}"
  echo ""
  echo -e "${C_DIM}Repo${C_RESET}    ${C_BOLD}${USER}/${REPO}${C_RESET}"
  echo -e "${C_DIM}Default${C_RESET} ${C_GREEN}${DEFAULT_BRANCH}${C_RESET}"
  echo ""
}

# ===== Menu utama =====
show_main_menu() {
  banner
  echo -e "${C_BOLD}🚀 GitHub:${C_RESET} ${C_CYAN}${USER}/${REPO}${C_RESET}"
  echo ""
  echo -e "  ${C_GREEN}1${C_RESET} upload script ${C_DIM}(pilih branch tujuan)${C_RESET}"
  echo -e "  ${C_CYAN}2${C_RESET} buat branch baru"
  echo -e "  ${C_YELLOW}3${C_RESET} hapus branch ${C_DIM}(default dilindungi)${C_RESET}"
  echo -e "  ${C_MAGENTA}4${C_RESET} ganti default branch ${C_DIM}(sekarang: ${DEFAULT_BRANCH})${C_RESET}"
  echo -e "  ${C_BLUE}5${C_RESET} rename repository ${C_DIM}(sekarang: ${REPO})${C_RESET}"
  echo -e "  ${C_RED}0${C_RESET} keluar"
  echo ""
  printf "${C_BOLD}Pilih [0/1/2/3/4/5] ▸ ${C_RESET}"

  local pick
  read -r pick
  pick="${pick:-1}"

  case "$pick" in
    1) show_menu; run_upload ;;
    2) action_create_branch ;;
    3) action_delete_branch ;;
    4) action_switch_default ;;
    5) action_rename_repo ;;
    0|q|Q|exit) goodbye_prompt ;;
    *)
      echo -e "${C_RED}✖ Pilihan tidak valid: '${pick}'${C_RESET}"
      sleep 1
      ;;
  esac
}

# ===== Action: rename repository =====
action_rename_repo() {
  banner
  echo -e "${C_BOLD}✏️  Rename Repository${C_RESET}"
  echo -e "${C_DIM}Nama sekarang: ${C_CYAN}${USER}/${REPO}${C_RESET}"
  echo ""
  echo -e "  ${C_RED}0${C_RESET} ${C_DIM}kembali ke menu${C_RESET}"
  echo ""
  printf "${C_BOLD}Nama baru untuk repository ▸ ${C_RESET}"

  local new_name
  read -r new_name
  new_name=$(echo "$new_name" | tr -d '[:space:]')

  if [ -z "$new_name" ] || [ "$new_name" = "0" ]; then
    echo -e "${C_YELLOW}↩ Kembali ke menu.${C_RESET}"
    sleep 1
    return
  fi

  # Validasi: hanya huruf, angka, - dan _
  if ! echo "$new_name" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    echo -e "${C_RED}✖ Nama tidak valid${C_RESET} ${C_DIM}(hanya huruf, angka, - dan _)${C_RESET}"
    sleep 2
    return
  fi

  if [ "$new_name" = "$REPO" ]; then
    echo -e "${C_YELLOW}ℹ️  Nama sama seperti sekarang, tidak ada yang diubah.${C_RESET}"
    sleep 2
    return
  fi

  # Konfirmasi
  echo ""
  echo -e "${C_RED}⚠️  Yakin rename repository?${C_RESET}"
  echo -e "     ${C_DIM}${USER}/${REPO}${C_RESET} ${C_BOLD}→${C_RESET} ${C_GREEN}${USER}/${new_name}${C_RESET}"
  echo -e "  ${C_DIM}Remote URL akan otomatis diperbarui di lokal juga.${C_RESET}"
  echo ""
  echo -e "  ${C_GREEN}1${C_RESET} ${C_DIM}lanjut rename${C_RESET}"
  echo -e "  ${C_RED}0${C_RESET} ${C_DIM}batal${C_RESET}"
  printf "${C_BOLD}Konfirmasi ▸ ${C_RESET}"
  local confirm
  read -r confirm
  if [ "$confirm" != "1" ]; then
    echo -e "${C_YELLOW}↩ Dibatalkan.${C_RESET}"
    sleep 1
    return
  fi

  echo ""
  echo -e "  ${C_CYAN}▸${C_RESET} Menghubungi GitHub API untuk rename repo..."

  local api_http
  api_http=$(curl -s -o /tmp/_gh_rename.json -w "%{http_code}" \
    -X PATCH \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${USER}/${REPO}" \
    -d "{\"name\":\"${new_name}\"}" 2>/dev/null)

  if [ "$api_http" = "200" ]; then
    local old_repo="$REPO"
    REPO="$new_name"

    # Update REPO di push.sh secara permanen
    sed -i "s|^REPO=.*|REPO=\"${new_name}\"|" "$0" 2>/dev/null || true

    # Update remote URL lokal agar tidak putus
    local new_url="https://${USER}:${TOKEN}@github.com/${USER}/${new_name}.git"
    git remote set-url origin "$new_url" 2>/dev/null || true

    echo ""
    echo -e "  ${C_GREEN}✅ Repository berhasil di-rename di GitHub!${C_RESET}"
    echo -e "     ${C_DIM}${USER}/${old_repo}${C_RESET} ${C_BOLD}→${C_RESET} ${C_GREEN}${USER}/${new_name}${C_RESET}"
    echo -e "  ${C_BLUE}🔗 https://github.com/${USER}/${new_name}${C_RESET}"
    echo -e "  ${C_DIM}Remote URL lokal sudah diperbarui otomatis.${C_RESET}"
    echo -e "  ${C_DIM}Perubahan nama disimpan permanen di push.sh${C_RESET}"
  else
    local api_msg
    api_msg=$(grep -o '"message":"[^"]*"' /tmp/_gh_rename.json 2>/dev/null | head -1 | sed 's/"message":"//;s/"//')
    echo ""
    echo -e "  ${C_RED}❌ Gagal rename repository (HTTP ${api_http})${C_RESET}"
    [ -n "$api_msg" ] && echo -e "  ${C_DIM}   GitHub: ${api_msg}${C_RESET}"
    echo -e "  ${C_DIM}   Pastikan token punya permission: delete_repo atau repo (full)${C_RESET}"
  fi

  rm -f /tmp/_gh_rename.json
  prompt_back_or_exit
}

# ===== Action: ganti default branch =====
action_switch_default() {
  banner
  echo -e "${C_BOLD}🔀 Ganti Default Branch${C_RESET}"
  echo -e "${C_DIM}Default sekarang: ${C_GREEN}${DEFAULT_BRANCH}${C_RESET}"
  echo ""

  local branches=()
  while IFS= read -r b; do
    [ -n "$b" ] && [ "$b" != "$DEFAULT_BRANCH" ] && branches+=("$b")
  done < <(fetch_branches)

  local total=${#branches[@]}
  if [ "$total" -eq 0 ]; then
    echo -e "${C_YELLOW}ℹ️  Tidak ada branch lain yang tersedia.${C_RESET}"
    prompt_back_or_exit
    return
  fi

  echo -e "${C_DIM}Pilih branch yang akan jadi default baru:${C_RESET}"
  echo ""
  local i=1
  for b in "${branches[@]}"; do
    printf "  ${C_CYAN}%2d${C_RESET} %s\n" "$i" "$b"
    i=$((i + 1))
  done
  echo ""
  echo -e "  ${C_RED} 0${C_RESET} ${C_DIM}kembali ke menu${C_RESET}"
  echo ""
  printf "${C_BOLD}Pilih [1-${total}] ▸ ${C_RESET}"

  local pick
  read -r pick
  pick="${pick:-0}"

  if [ "$pick" = "0" ]; then
    echo -e "${C_YELLOW}↩ Kembali ke menu.${C_RESET}"
    sleep 1
    return
  fi

  if ! echo "$pick" | grep -qE '^[0-9]+$' || [ "$pick" -lt 1 ] || [ "$pick" -gt "$total" ]; then
    echo -e "${C_RED}✖ Pilihan tidak valid.${C_RESET}"
    sleep 2
    return
  fi

  local new_default="${branches[$((pick - 1))]}"
  local old_default="$DEFAULT_BRANCH"

  echo ""
  echo -e "  ${C_CYAN}▸${C_RESET} Menghubungi GitHub API untuk ganti default branch..."

  # Panggil GitHub API untuk benar-benar ganti default branch di remote
  local api_resp api_http
  api_resp=$(curl -s -o /tmp/_gh_switch.json -w "%{http_code}" \
    -X PATCH \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${USER}/${REPO}" \
    -d "{\"default_branch\":\"${new_default}\"}" 2>/dev/null)
  api_http="${api_resp}"

  if [ "$api_http" = "200" ]; then
    # Sukses — update variabel lokal & simpan ke push.sh
    DEFAULT_BRANCH="$new_default"
    sed -i "s|^DEFAULT_BRANCH=.*|DEFAULT_BRANCH=\"${new_default}\"|" "$0" 2>/dev/null || true

    echo ""
    echo -e "  ${C_GREEN}✅ Default branch berhasil diubah di GitHub!${C_RESET}"
    echo -e "     ${C_DIM}${old_default}${C_RESET} ${C_BOLD}→${C_RESET} ${C_GREEN}${new_default}${C_RESET}"
    echo -e "  ${C_BLUE}🔗 https://github.com/${USER}/${REPO}${C_RESET}"
    echo -e "  ${C_DIM}Perubahan juga disimpan permanen di push.sh${C_RESET}"
  else
    # Gagal — tampilkan error dari API
    local api_msg
    api_msg=$(grep -o '"message":"[^"]*"' /tmp/_gh_switch.json 2>/dev/null | head -1 | sed 's/"message":"//;s/"//')
    echo ""
    echo -e "  ${C_RED}❌ Gagal ubah default branch di GitHub (HTTP ${api_http})${C_RESET}"
    [ -n "$api_msg" ] && echo -e "  ${C_DIM}   GitHub: ${api_msg}${C_RESET}"
    echo -e "  ${C_DIM}   Pastikan token punya permission: repo (write access)${C_RESET}"
  fi

  rm -f /tmp/_gh_switch.json
  prompt_back_or_exit
}

# ===== Action: buat branch baru =====
action_create_branch() {
  banner
  echo -e "${C_BOLD}🌱 Buat branch baru${C_RESET}"
  echo ""
  echo -e "  ${C_RED}0${C_RESET} ${C_DIM}kembali ke menu${C_RESET}"
  echo ""
  printf "${C_BOLD}Nama branch baru ▸ ${C_RESET}"
  local name
  read -r name
  name=$(echo "$name" | tr -d '[:space:]')

  if [ -z "$name" ] || [ "$name" = "0" ]; then
    echo -e "${C_YELLOW}↩ Kembali ke menu.${C_RESET}"
    sleep 1
    return
  fi

  # Validasi nama (hanya alfanumerik, -, _, /, .)
  if ! echo "$name" | grep -qE '^[a-zA-Z0-9._/-]+$'; then
    echo -e "${C_RED}✖ Nama tidak valid${C_RESET} ${C_DIM}(hanya huruf, angka, - _ / .)${C_RESET}"
    sleep 2
    return
  fi

  # Cek apakah branch sudah ada via GitHub API
  local chk_http
  chk_http=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${USER}/${REPO}/git/ref/heads/${name}" \
    2>/dev/null)
  if [ "$chk_http" = "200" ]; then
    echo -e "${C_RED}✖ Branch '${name}' sudah ada di GitHub.${C_RESET}"
    sleep 2
    return
  fi

  echo ""
  echo -e "  ${C_CYAN}▸${C_RESET} ambil SHA dari ${DEFAULT_BRANCH}..."

  # Ambil SHA tip dari DEFAULT_BRANCH via GitHub API (tidak butuh switch branch lokal)
  local sha_resp sha_http sha
  sha_resp=$(curl -s -o /tmp/_gh_sha.json -w "%{http_code}" \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${USER}/${REPO}/git/ref/heads/${DEFAULT_BRANCH}" \
    2>/dev/null)

  if [ "$sha_resp" != "200" ]; then
    echo -e "${C_RED}✖ Gagal ambil SHA branch ${DEFAULT_BRANCH} (HTTP ${sha_resp})${C_RESET}"
    rm -f /tmp/_gh_sha.json
    sleep 2
    return
  fi

  sha=$(grep -o '"sha": *"[^"]*"' /tmp/_gh_sha.json | head -1 | sed 's/"sha": *"//;s/"//')
  rm -f /tmp/_gh_sha.json

  if [ -z "$sha" ]; then
    echo -e "${C_RED}✖ SHA tidak ditemukan dari response GitHub${C_RESET}"
    sleep 2
    return
  fi

  echo -e "  ${C_DIM}   SHA: ${sha:0:10}...${C_RESET}"
  echo -e "  ${C_CYAN}▸${C_RESET} bikin branch ${C_BOLD}${name}${C_RESET} via GitHub API..."

  # Buat branch di GitHub via API — tanpa perlu git checkout lokal
  local create_http
  create_http=$(curl -s -o /tmp/_gh_create.json -w "%{http_code}" \
    -X POST \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${USER}/${REPO}/git/refs" \
    -d "{\"ref\":\"refs/heads/${name}\",\"sha\":\"${sha}\"}" \
    2>/dev/null)

  if [ "$create_http" = "201" ]; then
    echo ""
    echo -e "  ${C_GREEN}🎉 Branch '${name}' berhasil dibuat di GitHub!${C_RESET}"
    echo -e "  ${C_BLUE}🔗 https://github.com/${USER}/${REPO}/tree/${name}${C_RESET}"
  else
    local api_msg
    api_msg=$(grep -o '"message": *"[^"]*"' /tmp/_gh_create.json 2>/dev/null | head -1 | sed 's/"message": *"//;s/"//')
    echo -e "  ${C_RED}❌ Gagal buat branch (HTTP ${create_http})${C_RESET}"
    [ -n "$api_msg" ] && echo -e "  ${C_DIM}   GitHub: ${api_msg}${C_RESET}"
  fi
  rm -f /tmp/_gh_create.json

  prompt_back_or_exit
}

# ===== Action: hapus branch =====
action_delete_branch() {
  banner
  echo -e "${C_BOLD}🗑️  Hapus branch${C_RESET} ${C_DIM}(default '${DEFAULT_BRANCH}' dilindungi)${C_RESET}"
  echo ""

  local branches=()
  while IFS= read -r b; do
    [ -n "$b" ] && [ "$b" != "$DEFAULT_BRANCH" ] && branches+=("$b")
  done < <(fetch_branches)

  local total=${#branches[@]}
  if [ "$total" -eq 0 ]; then
    echo -e "${C_YELLOW}ℹ️  Tidak ada branch yang bisa dihapus${C_RESET}"
    echo -e "${C_DIM}   (cuma branch default '${DEFAULT_BRANCH}' yang ada)${C_RESET}"
    prompt_back_or_exit
    return
  fi

  echo -e "${C_DIM}Branch yang bisa dihapus (${total}):${C_RESET}"
  local i=1
  for b in "${branches[@]}"; do
    printf "  ${C_YELLOW}%2d${C_RESET} %s\n" "$i" "$b"
    i=$((i + 1))
  done
  echo ""
  echo -e "  ${C_DIM}Multi-hapus: pisahkan nomor dengan koma/spasi${C_RESET}"
  echo -e "  ${C_DIM}Contoh: ${C_BOLD}1,3${C_RESET}${C_DIM}  atau  ${C_BOLD}1 2 3${C_RESET}${C_DIM}  atau  ${C_BOLD}all${C_RESET}${C_DIM} (semua)${C_RESET}"
  echo ""
  echo -e "  ${C_RED}0${C_RESET} ${C_DIM}kembali ke menu${C_RESET}"
  echo ""
  printf "${C_BOLD}Pilih branch ▸ ${C_RESET}"

  local pick
  read -r pick
  pick="${pick:-0}"

  if [ "$pick" = "0" ]; then
    echo -e "${C_YELLOW}↩ Kembali ke menu.${C_RESET}"
    sleep 1
    return
  fi

  # ===== Parse pilihan (bisa "1,3" / "1 3" / "all" / "1") =====
  local targets=()
  local invalid=()

  if [ "$pick" = "all" ] || [ "$pick" = "ALL" ] || [ "$pick" = "a" ] || [ "$pick" = "A" ]; then
    targets=("${branches[@]}")
  else
    # Ganti koma jadi spasi, lalu split
    local normalized
    normalized=$(echo "$pick" | tr ',;' '  ')
    local seen=" "
    for n in $normalized; do
      if echo "$n" | grep -qE '^[0-9]+$' && [ "$n" -ge 1 ] && [ "$n" -le "$total" ]; then
        local b="${branches[$((n - 1))]}"
        # Hindari duplikat
        case "$seen" in
          *" $n "*) ;;
          *) targets+=("$b"); seen="$seen$n " ;;
        esac
      else
        invalid+=("$n")
      fi
    done
  fi

  # Notif kalau ada nomor invalid
  if [ ${#invalid[@]} -gt 0 ]; then
    echo ""
    echo -e "${C_RED}✖ Nomor tidak valid: ${invalid[*]}${C_RESET} ${C_DIM}(range valid: 1-${total})${C_RESET}"
    if [ ${#targets[@]} -eq 0 ]; then
      echo -e "${C_YELLOW}↩ Tidak ada branch dipilih, kembali ke menu.${C_RESET}"
      sleep 2
      return
    else
      echo -e "${C_DIM}   Lanjut hapus yang valid saja...${C_RESET}"
      sleep 1
    fi
  fi

  if [ ${#targets[@]} -eq 0 ]; then
    echo -e "${C_RED}✖ Tidak ada pilihan valid.${C_RESET}"
    sleep 2
    return
  fi

  # ===== Konfirmasi =====
  echo ""
  echo -e "${C_RED}⚠️  Yakin hapus ${#targets[@]} branch berikut dari lokal & remote?${C_RESET}"
  for t in "${targets[@]}"; do
    echo -e "    ${C_YELLOW}•${C_RESET} ${C_BOLD}${t}${C_RESET}"
  done
  echo ""
  echo -e "  ${C_GREEN}1${C_RESET} ${C_DIM}lanjut hapus${C_RESET}"
  echo -e "  ${C_RED}0${C_RESET} ${C_DIM}batal & kembali ke menu${C_RESET}"
  printf "${C_BOLD}Konfirmasi ▸ ${C_RESET}"
  local confirm
  read -r confirm

  if [ "$confirm" != "1" ]; then
    echo -e "${C_YELLOW}↩ Dibatalkan, kembali ke menu.${C_RESET}"
    sleep 1
    return
  fi

  # Pindah dulu ke default biar aman
  git checkout -q "$DEFAULT_BRANCH" 2>/dev/null || true

  local ok=0 fail=0
  for target in "${targets[@]}"; do
    # Proteksi terakhir untuk default
    if [ "$target" = "$DEFAULT_BRANCH" ]; then
      echo ""
      echo -e "  ${C_RED}✖ '${target}' adalah branch default — dilewati.${C_RESET}"
      fail=$((fail + 1))
      continue
    fi

    echo ""
    echo -e "${C_BOLD}🗑️  ${target}${C_RESET}"
    echo -e "  ${C_CYAN}▸${C_RESET} hapus lokal..."
    if git branch -D "$target" 2>/dev/null; then
      echo -e "  ${C_GREEN}✅ lokal terhapus${C_RESET}"
    else
      echo -e "  ${C_DIM}ℹ️  branch lokal tidak ada / sudah terhapus${C_RESET}"
    fi

    echo -e "  ${C_CYAN}▸${C_RESET} hapus remote..."
    local del_log
    del_log=$(mktemp)
    if git push origin --delete "$target" >"$del_log" 2>&1; then
      echo -e "  ${C_GREEN}✅ remote terhapus${C_RESET}"
      ok=$((ok + 1))
    else
      echo -e "  ${C_RED}❌ Gagal hapus remote${C_RESET}"
      echo -e "  ${C_DIM}── error log ──${C_RESET}"
      sed 's/^/    /' "$del_log" | tail -5
      fail=$((fail + 1))
    fi
    rm -f "$del_log"
  done

  # ===== Ringkasan =====
  echo ""
  echo -e "${C_BOLD}─── Ringkasan ───${C_RESET}"
  echo -e "  ${C_GREEN}✅ Sukses : ${ok}${C_RESET}"
  [ "$fail" -gt 0 ] && echo -e "  ${C_RED}❌ Gagal  : ${fail}${C_RESET}"

  prompt_back_or_exit
}

# ===== Menu pemilih branch (sub-menu dari opsi 1) =====
show_menu() {
  banner

  local branches=()
  while IFS= read -r b; do
    [ -n "$b" ] && branches+=("$b")
  done < <(fetch_branches)

  local total=${#branches[@]}
  echo -e "${C_BOLD}Pilih branch tujuan upload${C_RESET} ${C_DIM}(${USER}/${REPO} • total ${total})${C_RESET}"

  local i=1
  for b in "${branches[@]}"; do
    if [ "$b" = "$DEFAULT_BRANCH" ]; then
      printf "  ${C_GREEN}%2d${C_RESET} %s ${C_DIM}(default)${C_RESET}\n" "$i" "$b"
    else
      printf "  ${C_CYAN}%2d${C_RESET} %s\n" "$i" "$b"
    fi
    i=$((i + 1))
  done

  echo ""
  echo -e "  ${C_YELLOW} A${C_RESET} upload ke ${C_BOLD}semua branch${C_RESET}"
  echo -e "  ${C_GREEN} D${C_RESET} pakai default (${DEFAULT_BRANCH})"
  echo -e "  ${C_RED} 0${C_RESET} kembali"
  echo ""
  printf "${C_BOLD}Pilihan ▸ ${C_RESET}"

  local choice
  read -r choice
  choice="${choice:-D}"

  case "$choice" in
    0|q|Q|exit)
      goodbye_prompt
      ;;
    a|A)
      SELECTED_BRANCHES=("${branches[@]}")
      ;;
    d|D|"")
      SELECTED_BRANCHES=("$DEFAULT_BRANCH")
      ;;
    *[!0-9]*)
      echo -e "${C_RED}✖ Pilihan tidak valid: '${choice}'${C_RESET} ${C_DIM}(hanya angka, A, D, atau 0)${C_RESET}"
      sleep 1
      show_menu
      return
      ;;
    *)
      if [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
        SELECTED_BRANCHES=("${branches[$((choice - 1))]}")
      else
        echo -e "${C_RED}✖ Nomor ${choice} di luar range${C_RESET} ${C_DIM}(1-${total})${C_RESET}"
        sleep 1
        show_menu
        return
      fi
      ;;
  esac
}

# ===== Goodbye prompt (bisa balik cepat dengan ketik 1) =====
goodbye_prompt() {
  echo ""
  echo -e "${C_DIM}─────────────────────────────────────${C_RESET}"
  echo -e "${C_BOLD}ℹ️  Keluar.${C_RESET}"
  echo -e "  ${C_GREEN}1${C_RESET} ${C_DIM}masuk lagi${C_RESET}"
  echo -e "  ${C_RED}0${C_RESET} ${C_DIM}benar-benar keluar${C_RESET}"
  printf "${C_BOLD}▸ ${C_RESET}"
  local back
  read -r back
  back="${back:-1}"
  case "$back" in
    1|y|Y|yes|menu|m|M)
      main_loop
      ;;
    *)
      echo -e "${C_DIM}Bye 👋${C_RESET}"
      exit 0
      ;;
  esac
}

# ===== Commit semua perubahan pending di branch SEKARANG (sekali, sebelum loop push) =====
# Return 0 = ada/tidak ada perubahan, semua handled. Return 1 = error fatal.
# Set var global: COMMIT_DONE (yes/no), HEAD_SHA
commit_pending_changes() {
  COMMIT_DONE="no"

  # ===== STEP 1: Scan working tree real-time =====
  local pre_scan
  pre_scan=$(scan_changes)
  count_changes "$pre_scan"
  local pre_total=$CH_TOTAL

  echo -e "${C_BOLD}🔍 Scan working tree${C_RESET} ${C_DIM}(branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null))${C_RESET}"

  if [ "$pre_total" -gt 0 ]; then
    echo -e "  ${C_CYAN}▸${C_RESET} ${C_BOLD}${pre_total}${C_RESET} file berubah ${C_DIM}(➕${CH_NEW} ✏️${CH_MOD} ❌${CH_DEL} ⚙️${CH_REN})${C_RESET}"
    print_changes_preview
  else
    echo -e "  ${C_DIM}▸ 0 perubahan di working tree${C_RESET}"
  fi

  # ===== STEP 1.5: Scan file yang ke-ignore tapi baru diubah (warning aja) =====
  scan_ignored_recent
  print_ignored_preview

  # ===== STEP 2: Stage semua perubahan =====
  if ! prepare_stage; then
    echo -e "  ${C_RED}❌ Gagal stage perubahan${C_RESET}"
    return 1
  fi

  # ===== STEP 3: Verifikasi index =====
  local has_staged="no"
  if ! git diff --cached --quiet 2>/dev/null; then
    has_staged="yes"
  fi

  if [ "$pre_total" -gt 0 ] && [ "$has_staged" = "no" ]; then
    echo -e "  ${C_YELLOW}⚠️  ${pre_total} file berubah di disk tapi tidak ke-stage${C_RESET}"
    echo -e "  ${C_DIM}   → biasanya ke-block .gitignore. Liat warning '🚫' di atas.${C_RESET}"
  fi

  # ===== STEP 4: Commit kalau ada yang di-stage =====
  if [ "$has_staged" = "yes" ]; then
    local staged_total
    staged_total=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${C_CYAN}▸${C_RESET} ${C_BOLD}${staged_total}${C_RESET} file di-stage, commit..."

    local MSG
    if [ -n "$CUSTOM_MSG" ]; then
      MSG="$CUSTOM_MSG"
    else
      MSG=$(classify_commit)
    fi

    if ! git commit -q -m "$MSG" 2>/dev/null; then
      echo -e "  ${C_RED}❌ git commit gagal${C_RESET}"
      return 1
    fi
    echo -e "  ${C_GREEN}✅${C_RESET} ${MSG}"
    COMMIT_DONE="yes"
  fi

  HEAD_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
  return 0
}

# ===== Push HEAD lokal ke branch tujuan di remote (TANPA pindah branch lokal) =====
# Pakai pushspec `HEAD:refs/heads/<branch>` → kirim apapun yang lagi di HEAD
# ke branch tujuan, gak peduli nama branch lokal apa. Ini bikin user bisa
# kerja di branch X dan upload ke main/V14/dll dengan konten yang sama persis.
push_head_to_branch() {
  local branch="$1"
  echo ""
  echo -e "${C_BOLD}${USER}/${REPO} → ${C_GREEN}${branch}${C_RESET}${C_BOLD} (upload HEAD ${HEAD_SHA})${C_RESET}"

  # Cek apakah HEAD sudah sama dengan origin/branch (no-op).
  git fetch origin "$branch" --quiet 2>/dev/null || true
  if git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
    local local_sha remote_sha
    local_sha=$(git rev-parse HEAD 2>/dev/null)
    remote_sha=$(git rev-parse "refs/remotes/origin/${branch}" 2>/dev/null)
    if [ "$local_sha" = "$remote_sha" ] && [ "$COMMIT_DONE" = "no" ]; then
      echo -e "  ${C_DIM}ℹ️  HEAD sudah identik dengan origin/${branch}${C_RESET}"
      echo -e "  ${C_GREEN}✅ Sudah up-to-date${C_RESET} → ${C_BLUE}https://github.com/${USER}/${REPO}/tree/${branch}${C_RESET}"
      return 0
    fi
  fi

  echo -e "  ${C_CYAN}▸${C_RESET} push HEAD → refs/heads/${branch}..."
  local push_log
  push_log=$(mktemp)

  # Coba normal push dulu (fast-forward).
  if git push origin "HEAD:refs/heads/${branch}" >"$push_log" 2>&1; then
    rm -f "$push_log"
    echo -e "  ${C_GREEN}🎉 Sukses!${C_RESET} ${C_BOLD}${branch}${C_RESET} ${C_DIM}(${HEAD_SHA})${C_RESET}"
    echo -e "  ${C_BLUE}🔗 https://github.com/${USER}/${REPO}/tree/${branch}${C_RESET}"
    return 0
  fi

  # Gagal — kemungkinan non-fast-forward. Coba force push.
  echo -e "  ${C_YELLOW}⚠️  Push normal gagal (kemungkinan branch divergent), force push...${C_RESET}"
  if git push --force origin "HEAD:refs/heads/${branch}" >"$push_log" 2>&1; then
    rm -f "$push_log"
    echo -e "  ${C_GREEN}🎉 Sukses (force)!${C_RESET} ${C_BOLD}${branch}${C_RESET} ${C_DIM}(${HEAD_SHA})${C_RESET}"
    echo -e "  ${C_BLUE}🔗 https://github.com/${USER}/${REPO}/tree/${branch}${C_RESET}"
    return 0
  fi

  # Deteksi error khusus: GitHub Secret Scanning
  if grep -q "secret" "$push_log" 2>/dev/null; then
    local unblock_url
    unblock_url=$(grep -o 'https://github.com[^ ]*unblock-secret[^ ]*' "$push_log" 2>/dev/null | head -1)
    echo ""
    echo -e "  ${C_RED}🔐 Push ditolak — GitHub menemukan token di history commit lama!${C_RESET}"
    echo -e "  ${C_DIM}   (.token.secret kamu AMAN — bukan itu masalahnya)${C_RESET}"
    echo ""
    echo -e "  ${C_BOLD}✅ Solusi: klik link ini lalu pilih 'Allow secret'${C_RESET}"
    if [ -n "$unblock_url" ]; then
      echo -e "  ${C_BLUE}${unblock_url}${C_RESET}"
    else
      echo -e "  ${C_DIM}Cek di: https://github.com/${USER}/${REPO}/security/secret-scanning${C_RESET}"
    fi
    echo -e "  ${C_DIM}   Setelah allow → jalankan push.sh lagi, langsung bisa.${C_RESET}"
    echo ""
  else
    echo -e "  ${C_RED}❌ Gagal push ke ${branch}${C_RESET}"
    echo -e "  ${C_DIM}── error log ──${C_RESET}"
    sed 's/^/    /' "$push_log" | tail -10
    echo ""
  fi
  rm -f "$push_log"
  return 1
}

# ===== Jalankan upload sesuai pilihan =====
# Alur baru: commit SEKALI di branch sekarang, lalu push HEAD itu ke
# semua branch tujuan. Gak ada switch branch — kerjamu aman.
run_upload() {
  local count=${#SELECTED_BRANCHES[@]}
  local ok=0 fail=0

  if [ "$count" -gt 1 ]; then
    echo ""
    echo -e "${C_MAGENTA}▶ Mode multi-branch${C_RESET} ${C_DIM}(${count} branch tujuan • konten sama untuk semua)${C_RESET}"
  fi

  echo ""
  # Commit perubahan pending di branch SEKARANG (cuma sekali).
  if ! commit_pending_changes; then
    echo -e "${C_RED}❌ Commit gagal, batal push.${C_RESET}"
    return 1
  fi

  # Loop push HEAD ke semua branch tujuan.
  for b in "${SELECTED_BRANCHES[@]}"; do
    if push_head_to_branch "$b"; then
      ok=$((ok + 1))
    else
      fail=$((fail + 1))
    fi
  done

  if [ "$count" -gt 1 ]; then
    echo ""
    echo -e "${C_BOLD}─── Ringkasan ───${C_RESET}"
    echo -e "  ${C_GREEN}✅ Sukses : ${ok}${C_RESET}"
    [ "$fail" -gt 0 ] && echo -e "  ${C_RED}❌ Gagal  : ${fail}${C_RESET}"
  fi

  prompt_back_or_exit
}

# ===== Helper: prompt tunggal setelah setiap action =====
prompt_back_or_exit() {
  echo ""
  echo -e "  ${C_GREEN}1${C_RESET} ${C_DIM}kembali ke menu${C_RESET}"
  echo -e "  ${C_RED}0${C_RESET} ${C_DIM}keluar${C_RESET}"
  printf "${C_BOLD}▸ ${C_RESET}"
  local _ans
  read -r _ans
  _ans="${_ans:-1}"
  case "$_ans" in
    0|q|Q|exit) goodbye_prompt ;;
  esac
}

# ===== Loop menu utama =====
main_loop() {
  while true; do
    SELECTED_BRANCHES=()
    show_main_menu
  done
}

# ===== Trap Ctrl+C → tawarkan masuk lagi =====
on_interrupt() {
  echo ""
  echo -e "${C_YELLOW}⚠️  Dibatalkan (Ctrl+C).${C_RESET}"
  goodbye_prompt
}
trap on_interrupt INT

main_loop