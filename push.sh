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
DEFAULT_BRANCH="ReadswDika-V16.1"

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
  clear >/dev/tty 2>/dev/null || true
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
  clear >/dev/tty 2>/dev/null || true
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
  clear >/dev/tty 2>/dev/null || true
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

    # ── Layar 1: Pilih jenis token ──────────────────────────────────────────
    clear >/dev/tty 2>/dev/null || true
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
    echo -e "  ${C_BOLD}Pilih opsi:${C_RESET}" >&2
    echo "" >&2
    echo -e "  ${C_CYAN}[1]${C_RESET} ${C_BOLD}Classic Token${C_RESET}         ${C_DIM}— belum punya, buat baru  (ghp_...)${C_RESET}" >&2
    echo -e "  ${C_CYAN}[2]${C_RESET} ${C_BOLD}Fine-grained Token${C_RESET}    ${C_DIM}— belum punya, buat baru  (github_pat_...)${C_RESET}" >&2
    echo -e "  ${C_CYAN}[3]${C_RESET} ${C_BOLD}Sudah punya token${C_RESET}     ${C_DIM}— langsung paste token lama / yang sudah ada${C_RESET}" >&2
    # Opsi 4 hanya muncul kalau file .token.secret benar-benar ada
    if [ -f .token.secret ]; then
      echo -e "  ${C_RED}[4]${C_RESET} ${C_BOLD}Hapus token tersimpan${C_RESET} ${C_DIM}— reset .token.secret${C_RESET}" >&2
    fi
    echo -e "  ${C_DIM}[0]${C_RESET} ${C_DIM}Keluar${C_RESET}" >&2
    echo "" >&2
    echo -e "${C_DIM}  ─────────────────────────────────────────────────${C_RESET}" >&2
    if [ -f .token.secret ]; then
      printf "  ${C_BOLD}Pilih [0/1/2/3/4] ▸ ${C_RESET}" >&2
    else
      printf "  ${C_BOLD}Pilih [0/1/2/3] ▸ ${C_RESET}" >&2
    fi
    local _tok_type=""
    read -r _tok_type </dev/tty
    _tok_type=$(echo "$_tok_type" | tr -d '\n\r ')

    # ── Pilihan 0: keluar ────────────────────────────────────────────────────
    if [ "$_tok_type" = "0" ]; then
      echo "" >&2
      echo -e "  ${C_DIM}Keluar dari script.${C_RESET}" >&2
      exit 0
    fi

    # ── Pilihan 4: hapus token tersimpan ────────────────────────────────────
    if [ "$_tok_type" = "4" ]; then
      if [ -f .token.secret ]; then
        rm -f .token.secret
        clear >/dev/tty 2>/dev/null || true
        echo -e "${C_BOLD}╔══════════════════════════════════════════════════╗${C_RESET}" >&2
        echo -e "${C_BOLD}║        🔐  TOKEN GITHUB — BANG WILY              ║${C_RESET}" >&2
        echo -e "${C_BOLD}╚══════════════════════════════════════════════════╝${C_RESET}" >&2
        echo "" >&2
        echo -e "  ${C_GREEN}✅ .token.secret berhasil dihapus.${C_RESET}" >&2
        echo -e "  ${C_DIM}   Silakan pilih opsi 1, 2, atau 3 untuk memasukkan token baru.${C_RESET}" >&2
        echo "" >&2
        sleep 2
      fi
      tok=""
      continue
    fi

    # ── Pilihan 3: langsung paste, skip instruksi ────────────────────────────
    if [ "$_tok_type" = "3" ]; then
      clear >/dev/tty 2>/dev/null || true
      echo -e "${C_BOLD}╔══════════════════════════════════════════════════╗${C_RESET}" >&2
      echo -e "${C_BOLD}║        🔐  TOKEN GITHUB — BANG WILY              ║${C_RESET}" >&2
      echo -e "${C_BOLD}╚══════════════════════════════════════════════════╝${C_RESET}" >&2
      echo "" >&2
      echo -e "  ${C_DIM}Paste token kamu di bawah (Classic / Fine-grained, keduanya diterima).${C_RESET}" >&2
      echo -e "  ${C_DIM}Ketik ${C_RESET}${C_BOLD}0${C_RESET}${C_DIM} lalu Enter untuk kembali ke menu.${C_RESET}" >&2
      echo "" >&2
      echo -e "${C_DIM}  ─────────────────────────────────────────────────${C_RESET}" >&2
      printf "  ${C_BOLD}Paste token  [0 = kembali] ▸ ${C_RESET}" >&2

      local input_tok3=""
      read -rs input_tok3 </dev/tty
      echo "" >&2
      input_tok3=$(echo "$input_tok3" | tr -d '\n\r ')

      if [ "$input_tok3" = "0" ]; then
        tok=""
        continue
      fi

      if [ -z "$input_tok3" ] || echo "$input_tok3" | grep -qE '^(#|TOKEN_KAMU|ISI_TOKEN|CONTOH|<|your_)'; then
        echo -e "  ${C_RED}❌ Token kosong atau tidak valid. Coba lagi.${C_RESET}" >&2
        sleep 1
        tok=""
        continue
      fi

      # Auto-detect jenis token dari prefix
      local _det3_label="" _det3_color="$C_GREEN"
      case "$input_tok3" in
        ghp_*)          _det3_label="Classic Token  (ghp_...)" ;;
        github_pat_*)   _det3_label="Fine-grained Token  (github_pat_...)" ;;
        ghs_*)          _det3_label="Server-to-Server Token  (ghs_...)"; _det3_color="$C_YELLOW" ;;
        gho_*)          _det3_label="OAuth App Token  (gho_...)";         _det3_color="$C_YELLOW" ;;
        ghu_*)          _det3_label="OAuth User Token  (ghu_...)";        _det3_color="$C_YELLOW" ;;
        *)              _det3_label="Token tidak dikenal / format non-standar"; _det3_color="$C_RED" ;;
      esac

      printf '%s' "$input_tok3" > .token.secret
      clear >/dev/tty 2>/dev/null || true
      echo -e "${C_BOLD}╔══════════════════════════════════════════════════╗${C_RESET}" >&2
      echo -e "${C_BOLD}║        🔐  TOKEN GITHUB — BANG WILY              ║${C_RESET}" >&2
      echo -e "${C_BOLD}╚══════════════════════════════════════════════════╝${C_RESET}" >&2
      echo "" >&2
      echo -e "  ${C_DIM}Jenis token terdeteksi:${C_RESET}" >&2
      echo -e "  ${_det3_color}${C_BOLD}▶ ${_det3_label}${C_RESET}" >&2
      echo "" >&2
      echo -e "  ${C_GREEN}✅ Token disimpan ke .token.secret${C_RESET}" >&2
      echo -e "  ${C_DIM}   File ini gitignored — aman, tidak ke-upload ke GitHub${C_RESET}" >&2
      echo "" >&2
      sleep 1
      tok="$input_tok3"
      continue
    fi

    # ── Layar 2: Instruksi sesuai pilihan 1 / 2 ─────────────────────────────
    clear >/dev/tty 2>/dev/null || true
    echo -e "${C_BOLD}╔══════════════════════════════════════════════════╗${C_RESET}" >&2
    echo -e "${C_BOLD}║        🔐  TOKEN GITHUB — BANG WILY              ║${C_RESET}" >&2
    echo -e "${C_BOLD}╚══════════════════════════════════════════════════╝${C_RESET}" >&2
    echo "" >&2

    # URL pre-filled: name/note, scope/permissions sudah otomatis terisi saat dibuka
    local _all_scopes="repo,repo%3Astatus,repo_deployment,public_repo,repo%3Ainvite,security_events,workflow,write%3Apackages,read%3Apackages,delete%3Apackages,admin%3Aorg,write%3Aorg,read%3Aorg,manage_runners%3Aorg,admin%3Apublic_key,write%3Apublic_key,read%3Apublic_key,admin%3Arepo_hook,write%3Arepo_hook,read%3Arepo_hook,admin%3Aorg_hook,gist,notifications,user,read%3Auser,user%3Aemail,user%3Afollow,delete_repo,write%3Adiscussion,read%3Adiscussion,admin%3Aenterprise,manage_runners%3Aenterprise,manage_billing%3Aenterprise,read%3Aenterprise,scim%3Aenterprise,audit_log,read%3Aaudit_log,codespace,codespace%3Asecrets,copilot,manage_billing%3Acopilot,write%3Anetwork_configurations,read%3Anetwork_configurations,project,read%3Aproject,admin%3Agpg_key,write%3Agpg_key,read%3Agpg_key,admin%3Assh_signing_key,write%3Assh_signing_key,read%3Assh_signing_key"
    local _url_classic="https://github.com/settings/tokens/new?description=${REPO}&scopes=${_all_scopes}"
    local _url_finegrained="https://github.com/settings/personal-access-tokens/new?name=${REPO}&description=Token+push+script+WilyBot&repository_access=all&permissions%5Bcontents%5D=write&permissions%5Bmetadata%5D=read"

    if [ "$_tok_type" = "2" ]; then
      echo -e "  ${C_BOLD}Fine-grained Token${C_RESET} ${C_DIM}(berawalan github_pat_...)${C_RESET}" >&2
      echo "" >&2
      echo -e "  ${C_CYAN}1.${C_RESET} Buka URL ini ${C_DIM}(form sudah otomatis terisi)${C_RESET}:" >&2
      echo -e "     ${C_BLUE}${_url_finegrained}${C_RESET}" >&2
      echo "" >&2
      echo -e "  ${C_CYAN}2.${C_RESET} Cek isian yang sudah auto-terisi:" >&2
      echo -e "     ${C_DIM}• Token name       :${C_RESET} ${C_BOLD}${REPO}${C_RESET} ${C_DIM}(bisa diganti)${C_RESET}" >&2
      echo -e "     ${C_DIM}• Repository access:${C_RESET} ${C_BOLD}All repositories${C_RESET}" >&2
      echo -e "     ${C_DIM}• Contents         :${C_RESET} ${C_BOLD}Read and write${C_RESET} ${C_DIM}(sudah tercentang)${C_RESET}" >&2
      echo -e "     ${C_DIM}• Metadata         :${C_RESET} ${C_BOLD}Read-only${C_RESET} ${C_DIM}(sudah tercentang)${C_RESET}" >&2
      echo "" >&2
      echo -e "  ${C_CYAN}3.${C_RESET} Set ${C_BOLD}Expiration → No expiration${C_RESET} ${C_DIM}(disarankan)${C_RESET}" >&2
      echo "" >&2
      echo -e "  ${C_CYAN}4.${C_RESET} Scroll bawah → klik ${C_BOLD}Generate token${C_RESET} → copy token-nya" >&2
    else
      echo -e "  ${C_BOLD}Classic Token${C_RESET} ${C_DIM}(berawalan ghp_...)${C_RESET}" >&2
      echo "" >&2
      echo -e "  ${C_CYAN}1.${C_RESET} Buka URL ini ${C_DIM}(form sudah otomatis terisi)${C_RESET}:" >&2
      echo -e "     ${C_BLUE}${_url_classic}${C_RESET}" >&2
      echo "" >&2
      echo -e "  ${C_CYAN}2.${C_RESET} Cek isian yang sudah auto-terisi:" >&2
      echo -e "     ${C_DIM}• Note  :${C_RESET} ${C_BOLD}${REPO}${C_RESET} ${C_DIM}(bisa diganti)${C_RESET}" >&2
      echo -e "     ${C_DIM}• Scope :${C_RESET} ${C_BOLD}repo${C_RESET} ${C_DIM}(sudah tercentang — full control)${C_RESET}" >&2
      echo "" >&2
      echo -e "  ${C_CYAN}3.${C_RESET} Set ${C_BOLD}Expiration → No expiration${C_RESET} ${C_DIM}(disarankan)${C_RESET}" >&2
      echo "" >&2
      echo -e "  ${C_CYAN}4.${C_RESET} Scroll bawah → klik ${C_BOLD}Generate token${C_RESET} → copy token-nya" >&2
    fi

    echo "" >&2
    echo -e "  ${C_DIM}Ketik ${C_RESET}${C_BOLD}0${C_RESET}${C_DIM} lalu Enter untuk kembali ke menu awal.${C_RESET}" >&2
    echo -e "${C_DIM}  ─────────────────────────────────────────────────${C_RESET}" >&2
    printf "  ${C_BOLD}Paste token  [0 = kembali] ▸ ${C_RESET}" >&2

    local input_tok=""
    read -rs input_tok </dev/tty
    echo "" >&2
    input_tok=$(echo "$input_tok" | tr -d '\n\r ')

    if [ "$input_tok" = "0" ]; then
      tok=""
      continue
    fi

    if [ -z "$input_tok" ] || echo "$input_tok" | grep -qE '^(#|TOKEN_KAMU|ISI_TOKEN|CONTOH|<|your_)'; then
      echo -e "  ${C_RED}❌ Token kosong atau tidak valid. Coba lagi.${C_RESET}" >&2
      sleep 1
      tok=""
      continue
    fi

    # ── Auto-detect jenis token dari prefix ────────────────────────────────
    local _detected_type="" _detected_label="" _detected_color=""
    case "$input_tok" in
      ghp_*)
        _detected_type="classic"
        _detected_label="Classic Token  (ghp_...)"
        _detected_color="$C_GREEN"
        ;;
      github_pat_*)
        _detected_type="finegrained"
        _detected_label="Fine-grained Token  (github_pat_...)"
        _detected_color="$C_GREEN"
        ;;
      ghs_*)
        _detected_type="server"
        _detected_label="Server-to-Server Token  (ghs_...)"
        _detected_color="$C_YELLOW"
        ;;
      gho_*)
        _detected_type="oauth"
        _detected_label="OAuth App Token  (gho_...)"
        _detected_color="$C_YELLOW"
        ;;
      ghu_*)
        _detected_type="oauth_user"
        _detected_label="OAuth User Token  (ghu_...)"
        _detected_color="$C_YELLOW"
        ;;
      *)
        _detected_type="unknown"
        _detected_label="Token tidak dikenal / format non-standar"
        _detected_color="$C_RED"
        ;;
    esac

    # Cek mismatch: user pilih tipe X tapi paste token tipe Y
    local _mismatch=0
    if [ "$_tok_type" = "1" ] && [ "$_detected_type" != "classic" ]; then
      _mismatch=1
    elif [ "$_tok_type" = "2" ] && [ "$_detected_type" != "finegrained" ]; then
      _mismatch=1
    fi

    # ── Layar 3: Konfirmasi simpan ─────────────────────────────────────────
    clear >/dev/tty 2>/dev/null || true
    echo -e "${C_BOLD}╔══════════════════════════════════════════════════╗${C_RESET}" >&2
    echo -e "${C_BOLD}║        🔐  TOKEN GITHUB — BANG WILY              ║${C_RESET}" >&2
    echo -e "${C_BOLD}╚══════════════════════════════════════════════════╝${C_RESET}" >&2
    echo "" >&2
    echo -e "  ${C_DIM}Jenis token terdeteksi:${C_RESET}" >&2
    echo -e "  ${_detected_color}${C_BOLD}▶ ${_detected_label}${C_RESET}" >&2
    echo "" >&2

    if [ "$_mismatch" -eq 1 ]; then
      if [ "$_tok_type" = "1" ]; then
        echo -e "  ${C_YELLOW}⚠️  Kamu pilih Classic tapi paste token ${_detected_label}.${C_RESET}" >&2
      else
        echo -e "  ${C_YELLOW}⚠️  Kamu pilih Fine-grained tapi paste token ${_detected_label}.${C_RESET}" >&2
      fi
      echo -e "  ${C_DIM}   Token tetap disimpan — validasi ke GitHub akan menentukan.${C_RESET}" >&2
      echo "" >&2
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

# ===== Pilih repository dari daftar milik akun GitHub =====
# $1 = TOKEN yang sudah valid
# $2 = REPO saat ini (default/fallback)
# Output (stdout): nama repo yang dipilih
pick_repo() {
  local tok="$1"
  local cur_repo="$2"
  local _saved_repo_file=".repo.last"

  # ── Cek repo tersimpan dari sesi sebelumnya ──────────────────────────────
  local _saved_repo=""
  if [ -f "$_saved_repo_file" ]; then
    _saved_repo=$(tr -d '\n\r ' < "$_saved_repo_file")
  fi

  if [ -n "$_saved_repo" ]; then
    clear >/dev/tty 2>/dev/null || true
    echo -e "${C_BOLD}╔══════════════════════════════════════════════════╗${C_RESET}" >&2
    echo -e "${C_BOLD}║        📁  PILIH REPOSITORY — BANG WILY          ║${C_RESET}" >&2
    echo -e "${C_BOLD}╚══════════════════════════════════════════════════╝${C_RESET}" >&2
    echo "" >&2
    echo -e "  ${C_DIM}Repo terakhir yang dipakai:${C_RESET}" >&2
    echo -e "  ${C_GREEN}${C_BOLD}▶ ${_saved_repo}${C_RESET}" >&2
    echo "" >&2
    echo -e "${C_DIM}  ─────────────────────────────────────────────────${C_RESET}" >&2
    printf "  ${C_BOLD}Enter = pakai ini, ketik 'ganti' untuk pilih ulang ▸ ${C_RESET}" >&2
    local _saved_pick=""
    read -r _saved_pick </dev/tty
    _saved_pick=$(echo "$_saved_pick" | tr -d '\n\r ' | tr '[:upper:]' '[:lower:]')
    if [ "$_saved_pick" != "ganti" ]; then
      echo "$_saved_repo"
      return
    fi
    # Lanjut ke menu penuh di bawah
  fi

  # ── Ambil daftar repo dari GitHub API ───────────────────────────────────
  echo -e "${C_DIM}  📋 Mengambil daftar repo dari GitHub...${C_RESET}" >&2

  local http_code
  http_code=$(curl -s \
    -o /tmp/_gh_repos.json \
    -w "%{http_code}" \
    -H "Authorization: token ${tok}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/user/repos?type=owner&sort=updated&per_page=100" 2>/dev/null)

  if [ "$http_code" != "200" ]; then
    echo -e "  ${C_YELLOW}⚠️  Gagal ambil daftar repo (HTTP ${http_code}). Pakai: ${C_BOLD}${cur_repo}${C_RESET}" >&2
    rm -f /tmp/_gh_repos.json
    echo "$cur_repo"
    return
  fi

  # Ekstrak full_name lalu ambil bagian setelah "/" → nama repo saja
  local repo_names
  repo_names=$(grep -o '"full_name":"[^"]*"' /tmp/_gh_repos.json \
    | sed 's|"full_name":"[^/]*/||;s|"||g')
  rm -f /tmp/_gh_repos.json

  if [ -z "$repo_names" ]; then
    echo -e "  ${C_YELLOW}⚠️  Tidak ada repo ditemukan. Pakai: ${C_BOLD}${cur_repo}${C_RESET}" >&2
    echo "$cur_repo"
    return
  fi

  # ── Tampilkan menu daftar repo ───────────────────────────────────────────
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╔══════════════════════════════════════════════════╗${C_RESET}" >&2
  echo -e "${C_BOLD}║        📁  PILIH REPOSITORY — BANG WILY          ║${C_RESET}" >&2
  echo -e "${C_BOLD}╚══════════════════════════════════════════════════╝${C_RESET}" >&2
  echo "" >&2

  local i=1 cur_idx=0
  local repo_arr=()
  while IFS= read -r rname; do
    [ -z "$rname" ] && continue
    repo_arr+=("$rname")
    local marker=""
    if [ "$rname" = "$cur_repo" ]; then
      marker="  ${C_GREEN}← default script${C_RESET}"
      cur_idx=$i
    fi
    printf "  ${C_CYAN}[%2d]${C_RESET}  %-45s%b\n" "$i" "$rname" "$marker" >&2
    i=$(( i + 1 ))
  done <<< "$repo_names"

  local total=$(( i - 1 ))
  echo "" >&2
  echo -e "${C_DIM}  ─────────────────────────────────────────────────${C_RESET}" >&2
  echo -e "  ${C_DIM}[0] = pakai default (${cur_repo})${C_RESET}" >&2
  printf "  ${C_BOLD}Pilih nomor [0-%d] atau Enter = %s ▸ ${C_RESET}" "$total" "$cur_repo" >&2

  local pick=""
  read -r pick </dev/tty
  pick=$(echo "$pick" | tr -d '\n\r ')

  local chosen_repo=""

  if [ -z "$pick" ] || [ "$pick" = "0" ]; then
    chosen_repo="$cur_repo"
  elif echo "$pick" | grep -qE '^[0-9]+$' && [ "$pick" -ge 1 ] && [ "$pick" -le "$total" ]; then
    chosen_repo="${repo_arr[$(( pick - 1 ))]}"
  else
    echo -e "  ${C_YELLOW}⚠️  Pilihan tidak valid, pakai: ${C_BOLD}${cur_repo}${C_RESET}" >&2
    sleep 1
    chosen_repo="$cur_repo"
  fi

  # Simpan pilihan ke .repo.last agar run berikutnya tidak perlu pilih ulang
  printf '%s' "$chosen_repo" > "$_saved_repo_file"
  echo "$chosen_repo"
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

# Pilih repo tujuan push dari daftar GitHub (bisa Enter untuk skip)
REPO=$(pick_repo "$TOKEN" "$REPO")
echo "" >&2
echo -e "  ${C_BOLD}📁 Repository tujuan: ${C_GREEN}${REPO}${C_RESET}" >&2
echo "" >&2
sleep 1

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
                data \
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
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   🚀  PUSH SCRIPT — BANG WILY    │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "  ${C_DIM}repo   ${C_RESET}${C_BOLD}${USER}/${REPO}${C_RESET}"
  echo -e "  ${C_DIM}branch ${C_RESET}${C_GREEN}${DEFAULT_BRANCH}${C_RESET}"
  echo ""
}

# ===== Menu utama =====
show_main_menu() {
  banner
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo -e "  ${C_GREEN}1${C_RESET} ${C_BOLD}›${C_RESET} Upload ke branch"
  echo -e "  ${C_CYAN}2${C_RESET} ${C_BOLD}›${C_RESET} Buat branch baru"
  echo -e "  ${C_YELLOW}3${C_RESET} ${C_BOLD}›${C_RESET} Hapus branch"
  echo -e "  ${C_MAGENTA}4${C_RESET} ${C_BOLD}›${C_RESET} Ganti default  ${C_DIM}(${DEFAULT_BRANCH})${C_RESET}"
  echo -e "  ${C_BLUE}5${C_RESET} ${C_BOLD}›${C_RESET} Cek token"
  echo -e "  ${C_BLUE}6${C_RESET} ${C_BOLD}›${C_RESET} Rename repo    ${C_DIM}(${REPO})${C_RESET}"
  echo -e "  ${C_CYAN}7${C_RESET} ${C_BOLD}›${C_RESET} Edit nama branch"
  echo -e "  ${C_GREEN}8${C_RESET} ${C_BOLD}›${C_RESET} Status branch"
  echo -e "  ${C_YELLOW}9${C_RESET} ${C_BOLD}›${C_RESET} Buat repository baru"
  echo -e "  ${C_BLUE}10${C_RESET} ${C_BOLD}›${C_RESET} Import repository"
  echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Keluar"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"

  local pick
  read -r pick
  pick="${pick:-1}"

  case "$pick" in
    1) show_menu; run_upload ;;
    2) action_create_branch ;;
    3) action_delete_branch ;;
    4) action_switch_default ;;
    5) action_check_token ;;
    6) action_rename_repo ;;
    7) action_rename_branch ;;
    8) action_list_branches ;;
    9) action_create_repo ;;
    10) action_import_repo ;;
    0|q|Q|exit) goodbye_prompt ;;
    *)
      echo -e "${C_RED}✖ Pilihan tidak valid: '${pick}'${C_RESET}"
      sleep 1
      ;;
  esac
}

# ===== Action: cek status token =====
action_check_token() {
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   🔍  CEK STATUS TOKEN           │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""

  if [ ! -f .token.secret ]; then
    echo -e "  ${C_RED}❌ File .token.secret tidak ditemukan.${C_RESET}"
    echo -e "  ${C_DIM}   Jalankan script dulu untuk menyimpan token.${C_RESET}"
    prompt_back_or_exit
    return
  fi

  local tok
  tok=$(tr -d '\n\r ' < .token.secret)

  if [ -z "$tok" ]; then
    echo -e "  ${C_RED}❌ File .token.secret kosong.${C_RESET}"
    prompt_back_or_exit
    return
  fi

  local tok_type_label tok_type_color
  case "$tok" in
    ghp_*)        tok_type_label="Classic Token (ghp_...)";              tok_type_color="$C_GREEN"  ;;
    github_pat_*) tok_type_label="Fine-grained Token (github_pat_...)"; tok_type_color="$C_GREEN"  ;;
    ghs_*)        tok_type_label="Server-to-Server Token (ghs_...)";    tok_type_color="$C_YELLOW" ;;
    gho_*)        tok_type_label="OAuth App Token (gho_...)";           tok_type_color="$C_YELLOW" ;;
    ghu_*)        tok_type_label="OAuth User Token (ghu_...)";          tok_type_color="$C_YELLOW" ;;
    *)            tok_type_label="Format tidak dikenal";                tok_type_color="$C_RED"    ;;
  esac

  local tok_masked
  tok_masked="${tok:0:10}****${tok: -4}"

  echo -e "  ${C_DIM}Token   :${C_RESET} ${tok_masked}"
  echo -e "  ${C_DIM}Jenis   :${C_RESET} ${tok_type_color}${C_BOLD}${tok_type_label}${C_RESET}"
  echo ""
  echo -e "  ${C_CYAN}▸${C_RESET} Menghubungi GitHub API untuk validasi token..."
  echo ""

  local api_out
  api_out=$(curl -s -i \
    -H "Authorization: Bearer ${tok}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/user" 2>/dev/null)

  local http_code
  http_code=$(echo "$api_out" | head -1 | grep -oE '[0-9]{3}' | head -1)

  local headers body
  headers=$(printf '%s' "$api_out" | awk '/^\r?$/{exit} {print}')
  body=$(printf '%s' "$api_out" | awk 'BEGIN{f=0} /^\r?$/{f=1;next} f{print}')

  if [ "$http_code" = "200" ]; then
    local gh_login gh_name gh_type scopes
    gh_login=$(echo "$body" | grep -o '"login": *"[^"]*"' | head -1 | sed 's/"login": *"//;s/"//')
    gh_name=$(echo "$body"  | grep -o '"name": *"[^"]*"'  | head -1 | sed 's/"name": *"//;s/"//')
    gh_type=$(echo "$body"  | grep -o '"type": *"[^"]*"'  | head -1 | sed 's/"type": *"//;s/"//')
    scopes=$(echo "$headers" | grep -i 'x-oauth-scopes' | sed 's/.*: *//' | tr -d '\r')

    local rate_limit rate_remaining rate_reset rate_reset_fmt
    rate_limit=$(echo "$headers"     | grep -i 'x-ratelimit-limit:'     | sed 's/.*: *//' | tr -d '\r')
    rate_remaining=$(echo "$headers" | grep -i 'x-ratelimit-remaining:' | sed 's/.*: *//' | tr -d '\r')
    rate_reset=$(echo "$headers"     | grep -i 'x-ratelimit-reset:'     | sed 's/.*: *//' | tr -d '\r')
    rate_reset_fmt=""
    if [ -n "$rate_reset" ]; then
      rate_reset_fmt=$(date -d "@${rate_reset}" '+%H:%M:%S' 2>/dev/null \
        || date -r "$rate_reset" '+%H:%M:%S' 2>/dev/null \
        || echo "$rate_reset")
    fi

    echo -e "  ${C_GREEN}✅ Token VALID${C_RESET}"
    echo ""
    echo -e "${C_DIM}  ── Akun GitHub ────────────────────${C_RESET}"
    echo -e "  ${C_DIM}Username ${C_RESET}${C_BOLD}${gh_login}${C_RESET}"
    [ -n "$gh_name" ] && echo -e "  ${C_DIM}Nama     ${C_RESET}${gh_name}"
    [ -n "$gh_type" ] && echo -e "  ${C_DIM}Tipe     ${C_RESET}${gh_type}"
    echo ""
    echo -e "${C_DIM}  ── Token ──────────────────────────${C_RESET}"
    if [ -n "$scopes" ]; then
      echo -e "  ${C_DIM}Scopes   ${C_RESET}${C_GREEN}${scopes}${C_RESET}"
    else
      echo -e "  ${C_DIM}Scopes   ${C_RESET}${C_DIM}fine-grained / tidak via header${C_RESET}"
    fi
    echo ""
    echo -e "${C_DIM}  ── Rate Limit API ─────────────────${C_RESET}"
    [ -n "$rate_limit" ]     && echo -e "  ${C_DIM}Limit    ${C_RESET}${rate_limit} req/jam"
    [ -n "$rate_remaining" ] && echo -e "  ${C_DIM}Sisa     ${C_RESET}${C_CYAN}${rate_remaining}${C_RESET}"
    [ -n "$rate_reset_fmt" ] && echo -e "  ${C_DIM}Reset    ${C_RESET}${rate_reset_fmt}"
  else
    local api_msg
    api_msg=$(echo "$body" | grep -o '"message": *"[^"]*"' | head -1 | sed 's/"message": *"//;s/"//')
    echo -e "  ${C_RED}❌ Token TIDAK VALID atau kadaluarsa (HTTP ${http_code})${C_RESET}"
    [ -n "$api_msg" ] && echo -e "  ${C_DIM}   GitHub: ${api_msg}${C_RESET}"
    echo ""
    echo -e "  ${C_YELLOW}💡 Pilih opsi 1/2/3 di menu token untuk menyimpan token baru.${C_RESET}"
  fi

  echo ""
  prompt_back_or_exit
}

# ===== Action: rename repository =====
action_rename_repo() {
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   ✏️   RENAME REPOSITORY         │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "  ${C_DIM}sekarang  ${C_RESET}${C_BOLD}${USER}/${REPO}${C_RESET}"
  echo ""
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Kembali ke menu"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}Nama baru ▸ ${C_RESET}"

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
  echo -e "  ${C_RED}⚠️  Yakin rename?${C_RESET}"
  echo -e "  ${C_DIM}${USER}/${REPO}${C_RESET} ${C_BOLD}→${C_RESET} ${C_GREEN}${USER}/${new_name}${C_RESET}"
  echo -e "  ${C_DIM}Remote URL lokal ikut diperbarui otomatis.${C_RESET}"
  echo ""
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo -e "  ${C_GREEN}1${C_RESET} ${C_BOLD}›${C_RESET} Lanjut rename"
  echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Batal"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"
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
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   🔀  GANTI DEFAULT BRANCH       │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "  ${C_DIM}default   ${C_RESET}${C_GREEN}${DEFAULT_BRANCH}${C_RESET}"
  echo ""

  local branches=()
  while IFS= read -r b; do
    [ -n "$b" ] && [ "$b" != "$DEFAULT_BRANCH" ] && branches+=("$b")
  done < <(fetch_branches)

  local total=${#branches[@]}
  if [ "$total" -eq 0 ]; then
    echo -e "  ${C_YELLOW}ℹ️  Tidak ada branch lain yang tersedia.${C_RESET}"
    prompt_back_or_exit
    return
  fi

  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  local i=1
  for b in "${branches[@]}"; do
    printf "  ${C_CYAN}%2d${C_RESET} ${C_BOLD}›${C_RESET} %s\n" "$i" "$b"
    i=$((i + 1))
  done
  echo -e "  ${C_RED} 0${C_RESET} ${C_BOLD}›${C_RESET} Kembali ke menu"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"

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

# ===== Helper: format waktu relatif =====
_relative_time() {
  local ts="$1"
  local epoch_ts epoch_now diff
  epoch_ts=$(date -d "$ts" +%s 2>/dev/null \
    || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null \
    || echo "0")
  epoch_now=$(date +%s)
  [ "$epoch_ts" = "0" ] && echo "?" && return
  diff=$(( epoch_now - epoch_ts ))
  if   [ "$diff" -lt 60 ];     then echo "${diff}d lalu"
  elif [ "$diff" -lt 3600 ];   then echo "$(( diff / 60 ))m lalu"
  elif [ "$diff" -lt 86400 ];  then echo "$(( diff / 3600 ))j lalu"
  elif [ "$diff" -lt 172800 ]; then echo "kemarin"
  elif [ "$diff" -lt 604800 ]; then echo "$(( diff / 86400 ))h lalu"
  else echo "$(( diff / 604800 ))mg lalu"
  fi
}

# ===== Action: status semua branch (mirip halaman GitHub Branches) =====
action_list_branches() {
  local PAGE=1
  local PAGE_SIZE=5
  local TMP_LIST=/tmp/_gh_brlist_$$.json

  # ── _draw_header: cetak ulang header supaya DRY ─────────────────────────
  _draw_header() {
    clear >/dev/tty 2>/dev/null || true
    echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
    echo -e "${C_BOLD}│   📊  STATUS BRANCH              │${C_RESET}"
    echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
    echo ""
    echo -e "  ${C_DIM}repo  ${C_RESET}${C_BOLD}${USER}/${REPO}${C_RESET}"
  }

  # ════════════════════════════════════════════════════════════════════════
  # FASE 1 — Ambil semua branch + date, lalu sort terbaru dulu
  # ════════════════════════════════════════════════════════════════════════
  _draw_header
  echo ""
  echo -e "  ${C_DIM}▸ [1/3] Mengambil daftar branch...${C_RESET}"

  local http_code
  http_code=$(curl -s -o "$TMP_LIST" -w "%{http_code}" \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${USER}/${REPO}/branches?per_page=100" 2>/dev/null)

  if [ "$http_code" != "200" ]; then
    echo -e "  ${C_RED}❌ Gagal ambil branch list (HTTP ${http_code})${C_RESET}"
    rm -f "$TMP_LIST"
    prompt_back_or_exit
    return
  fi

  # Parsing JSON pakai node (tersedia karena project ini Node.js).
  # Hasilkan baris: "name<TAB>sha"  — dijamin benar meski JSON compact/minified.
  local all_names=() all_shas=()
  while IFS=$'\t' read -r _n _s; do
    all_names+=("$_n")
    all_shas+=("$_s")
  done < <(node -e "
    const d = require('fs').readFileSync('$TMP_LIST','utf8');
    JSON.parse(d).forEach(b => console.log(b.name + '\t' + b.commit.sha));
  " 2>/dev/null)
  rm -f "$TMP_LIST"

  if [ ${#all_names[@]} -eq 0 ]; then
    echo -e "  ${C_RED}❌ Tidak ada branch ditemukan.${C_RESET}"
    prompt_back_or_exit; return
  fi

  # ── Pisahkan default ────────────────────────────────────────────────────
  local def_sha=""
  local nd_names=() nd_shas=()
  for (( i=0; i<${#all_names[@]}; i++ )); do
    if [ "${all_names[$i]}" = "$DEFAULT_BRANCH" ]; then
      def_sha="${all_shas[$i]}"
    else
      nd_names+=("${all_names[$i]}")
      nd_shas+=("${all_shas[$i]}")
    fi
  done

  # ── [2/3] Ambil tanggal commit semua branch secara PARALEL ─────────────
  echo -e "  ${C_DIM}▸ [2/3] Mengambil tanggal semua branch (paralel)...${C_RESET}"

  local total_nd=${#nd_names[@]}
  # Default branch date
  local def_date="" def_rel="-"
  if [ -n "$def_sha" ]; then
    curl -s -o "/tmp/_gh_d_def_$$.json" \
      -H "Authorization: token ${TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/${USER}/${REPO}/git/commits/${def_sha}" 2>/dev/null &
  fi
  # Semua branch lain — paralel
  for (( i=0; i<total_nd; i++ )); do
    local sha="${nd_shas[$i]}"
    [ -z "$sha" ] && continue
    curl -s -o "/tmp/_gh_d_${i}_$$.json" \
      -H "Authorization: token ${TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/${USER}/${REPO}/git/commits/${sha}" 2>/dev/null &
  done
  wait  # tunggu semua curl selesai

  # ── helper ekstrak date dari file git/commits — handle spasi opsional ──
  _parse_date() {
    grep -oE '"date"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" | head -1 \
      | grep -oE '"[0-9]{4}-[^"]*"' | tr -d '"'
  }

  # Baca hasil default
  if [ -f "/tmp/_gh_d_def_$$.json" ]; then
    def_date=$(_parse_date "/tmp/_gh_d_def_$$.json")
    rm -f "/tmp/_gh_d_def_$$.json"
    [ -n "$def_date" ] && def_rel=$(_relative_time "$def_date")
  fi

  # Baca hasil tiap branch, kumpulkan: "isodate<TAB>name<TAB>sha"
  local all_dated=()
  for (( i=0; i<total_nd; i++ )); do
    local fname="/tmp/_gh_d_${i}_$$.json"
    local bdate=""
    if [ -f "$fname" ]; then
      bdate=$(_parse_date "$fname")
      rm -f "$fname"
    fi
    # Simpan "isodate<TAB>name<TAB>sha" — tanggal kosong jadi "0000"
    all_dated+=("${bdate:-0000-00-00T00:00:00Z}"$'\t'"${nd_names[$i]}"$'\t'"${nd_shas[$i]}")
  done

  # ── Sort descending by ISO date (string sort bekerja untuk ISO 8601) ──
  local sorted_dated=()
  while IFS= read -r line; do
    sorted_dated+=("$line")
  done < <(printf '%s\n' "${all_dated[@]}" | sort -r)

  # Rebuild array nd_names / nd_shas / nd_dates sudah terurut terbaru dulu
  nd_names=(); nd_shas=(); local nd_dates=()
  for entry in "${sorted_dated[@]}"; do
    local _d _n _s
    IFS=$'\t' read -r _d _n _s <<< "$entry"
    nd_names+=("$_n")
    nd_shas+=("$_s")
    nd_dates+=("$_d")
  done

  local total_other=${#nd_names[@]}
  local total_pages=$(( (total_other + PAGE_SIZE - 1) / PAGE_SIZE ))
  [ "$total_pages" -eq 0 ] && total_pages=1

  echo -e "  ${C_DIM}▸ [3/3] Siap — ${total_other} branch ditemukan${C_RESET}"
  sleep 0.4

  # ════════════════════════════════════════════════════════════════════════
  # FASE 2 — Loop tampilan dengan paginasi
  # ════════════════════════════════════════════════════════════════════════
  while true; do
    local start=$(( (PAGE - 1) * PAGE_SIZE ))
    local end=$(( start + PAGE_SIZE ))
    [ "$end" -gt "$total_other" ] && end="$total_other"
    local pg_label="${PAGE}/${total_pages}"

    # Loading header sementara API compare jalan
    _draw_header
    echo ""
    echo -e "${C_DIM}  ── Default ★ ─────────────────────────${C_RESET}"
    printf "  ${C_GREEN}★${C_RESET} ${C_BOLD}%-24s${C_RESET} ${C_DIM}%s${C_RESET}\n" "$DEFAULT_BRANCH" "$def_rel"
    echo ""
    echo -e "${C_DIM}  ── Branches (terbaru dulu) ── ${pg_label} ──${C_RESET}"
    echo -e "  ${C_DIM}▸ Mengambil behind/ahead...${C_RESET}"

    # ── Fetch compare per branch di halaman ini ─────────────────────────
    local page_names=() page_dates=() page_behind=() page_ahead=()
    for (( idx=start; idx<end; idx++ )); do
      local b="${nd_names[$idx]}"
      local bdate="${nd_dates[$idx]}"
      local b_enc
      b_enc=$(printf '%s' "$b" | sed 's|/|%2F|g')
      page_names+=("$b")
      page_dates+=("$bdate")

      # Compare: pakai ?per_page=1 agar commits[] kecil, simpan ke variabel
      # (tidak ada head -c sehingga tidak ada risiko potong di tengah JSON)
      local cmp_raw
      cmp_raw=$(curl -s \
        -H "Authorization: token ${TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/${USER}/${REPO}/compare/${DEFAULT_BRANCH}...${b_enc}?per_page=1" \
        2>/dev/null)

      local behind ahead
      behind=$(printf '%s' "$cmp_raw" | grep -oE '"behind_by":[[:space:]]*[0-9]+' \
               | head -1 | grep -oE '[0-9]+$')
      ahead=$(printf '%s' "$cmp_raw"  | grep -oE '"ahead_by":[[:space:]]*[0-9]+'  \
               | head -1 | grep -oE '[0-9]+$')

      page_behind+=("${behind:-?}")
      page_ahead+=("${ahead:-?}")
    done

    # ── Render final ─────────────────────────────────────────────────────
    _draw_header
    echo ""
    echo -e "${C_DIM}  ── Default ★ ─────────────────────────${C_RESET}"
    printf "  ${C_GREEN}★${C_RESET} ${C_BOLD}%-24s${C_RESET} ${C_DIM}%s${C_RESET}\n" "$DEFAULT_BRANCH" "$def_rel"
    echo ""
    echo -e "${C_DIM}  ── Branches (terbaru dulu) ── ${pg_label} ──${C_RESET}"

    if [ "$total_other" -eq 0 ]; then
      echo -e "  ${C_DIM}Tidak ada branch lain.${C_RESET}"
    else
      for (( pi=0; pi<${#page_names[@]}; pi++ )); do
        local name="${page_names[$pi]}"
        local bdate="${page_dates[$pi]}"
        local behind="${page_behind[$pi]}"
        local ahead="${page_ahead[$pi]}"

        # Relative time
        local rel="-"
        [[ "$bdate" != "0000"* ]] && [ -n "$bdate" ] && rel=$(_relative_time "$bdate")

        # Truncate nama
        local disp="$name"
        [ ${#disp} -gt 20 ] && disp="${disp:0:19}…"

        # Status ↓behind ↑ahead
        local st=""
        if [ "$behind" = "?" ]; then
          st="${C_DIM}?${C_RESET}"
        elif [ "$behind" = "0" ] && [ "$ahead" = "0" ]; then
          st="${C_GREEN}✓${C_RESET}"
        else
          [ "$behind" != "0" ] && st="${st}${C_RED}↓${behind}${C_RESET}"
          [ "$behind" != "0" ] && [ "$ahead" != "0" ] && st="${st} "
          [ "$ahead"  != "0" ] && st="${st}${C_CYAN}↑${ahead}${C_RESET}"
        fi

        printf "  %-22s %-11s " "$disp" "$rel"
        echo -e "$st"
      done
    fi

    # ── Navigasi ─────────────────────────────────────────────────────────
    echo ""
    echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
    if [ "$total_pages" -gt 1 ]; then
      [ "$PAGE" -lt "$total_pages" ] && \
        echo -e "  ${C_CYAN}n${C_RESET} ${C_BOLD}›${C_RESET} Berikutnya    ${C_DIM}l › Halaman terakhir (${total_pages})${C_RESET}"
      [ "$PAGE" -gt 1 ] && \
        echo -e "  ${C_CYAN}p${C_RESET} ${C_BOLD}›${C_RESET} Sebelumnya    ${C_DIM}f › Halaman pertama (1)${C_RESET}"
      echo -e "  ${C_DIM}atau ketik nomor halaman langsung (1–${total_pages})${C_RESET}"
    fi
    echo -e "  ${C_GREEN}r${C_RESET} ${C_BOLD}›${C_RESET} Refresh"
    echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Kembali ke menu"
    echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
    printf "  ${C_BOLD}▸ ${C_RESET}"

    local nav
    read -r nav
    nav=$(echo "$nav" | tr -d '\n\r ' | tr '[:upper:]' '[:lower:]')

    case "$nav" in
      n|next)    [ "$PAGE" -lt "$total_pages" ] && PAGE=$((PAGE + 1)) ;;
      p|prev)    [ "$PAGE" -gt 1 ]              && PAGE=$((PAGE - 1)) ;;
      f|first)   PAGE=1 ;;
      l|last)    PAGE=$total_pages ;;
      r|refresh)
        # Mulai ulang dari awal (re-fetch semua data)
        action_list_branches; return ;;
      0|q|exit)  return ;;
      [1-9]*)
        if echo "$nav" | grep -qE '^[0-9]+$' && \
           [ "$nav" -ge 1 ] && [ "$nav" -le "$total_pages" ]; then
          PAGE="$nav"
        fi
        ;;
    esac
  done
}

# ===== Action: buat repository baru =====
action_create_repo() {
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   📦  BUAT REPOSITORY BARU       │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "  ${C_DIM}akun  ${C_RESET}${C_BOLD}${USER}${C_RESET}"
  echo ""

  # ── 1) Nama repository ─────────────────────────────────────────────────
  echo -e "${C_DIM}  ── Nama Repository ─────────────────${C_RESET}"
  echo -e "  ${C_DIM}(hanya huruf, angka, - dan _  — tanpa spasi)${C_RESET}"
  local new_repo_name=""
  while true; do
    printf "  ${C_BOLD}▸ ${C_RESET}"
    read -r new_repo_name
    new_repo_name=$(echo "$new_repo_name" | tr -d '\n\r')
    if [ -z "$new_repo_name" ]; then
      echo -e "  ${C_RED}✖ Nama tidak boleh kosong.${C_RESET}"
    elif echo "$new_repo_name" | grep -qE '[^a-zA-Z0-9._-]'; then
      echo -e "  ${C_RED}✖ Nama mengandung karakter tidak valid.${C_RESET}"
    elif [ "${#new_repo_name}" -gt 100 ]; then
      echo -e "  ${C_RED}✖ Nama terlalu panjang (maks 100 karakter).${C_RESET}"
    else
      break
    fi
  done
  echo ""

  # ── 2) Deskripsi ────────────────────────────────────────────────────────
  echo -e "${C_DIM}  ── Deskripsi ${C_RESET}${C_DIM}(opsional, Enter untuk skip) ───${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"
  local new_desc=""
  read -r new_desc
  new_desc=$(echo "$new_desc" | tr -d '\n\r')
  echo ""

  # ── 3) Visibilitas ──────────────────────────────────────────────────────
  echo -e "${C_DIM}  ── Visibilitas ──────────────────────${C_RESET}"
  echo -e "  ${C_GREEN}1${C_RESET} ${C_BOLD}›${C_RESET} Private  ${C_DIM}(hanya kamu yang bisa akses)${C_RESET}"
  echo -e "  ${C_CYAN}2${C_RESET} ${C_BOLD}›${C_RESET} Public   ${C_DIM}(semua orang bisa lihat)${C_RESET}"
  local vis_pick="" is_private=true vis_label="Private"
  while true; do
    printf "  ${C_BOLD}▸ ${C_RESET}"
    read -r vis_pick
    vis_pick=$(echo "$vis_pick" | tr -d '\n\r ')
    case "$vis_pick" in
      1|"") is_private=true;  vis_label="🔒 Private"; break ;;
      2)    is_private=false; vis_label="🌐 Public";  break ;;
      *) echo -e "  ${C_RED}✖ Ketik 1 atau 2.${C_RESET}" ;;
    esac
  done
  echo ""

  # ── 4) README ───────────────────────────────────────────────────────────
  echo -e "${C_DIM}  ── Add README ───────────────────────${C_RESET}"
  echo -e "  ${C_GREEN}1${C_RESET} ${C_BOLD}›${C_RESET} Ya   ${C_DIM}(auto-init repo dengan README.md)${C_RESET}"
  echo -e "  ${C_CYAN}2${C_RESET} ${C_BOLD}›${C_RESET} Tidak"
  local readme_pick="" auto_init=false readme_label="Tidak"
  while true; do
    printf "  ${C_BOLD}▸ ${C_RESET}"
    read -r readme_pick
    readme_pick=$(echo "$readme_pick" | tr -d '\n\r ')
    case "$readme_pick" in
      1|"") auto_init=true;  readme_label="Ya"; break ;;
      2)    auto_init=false; readme_label="Tidak"; break ;;
      *) echo -e "  ${C_RED}✖ Ketik 1 atau 2.${C_RESET}" ;;
    esac
  done
  echo ""

  # ── 5) .gitignore template ──────────────────────────────────────────────
  echo -e "${C_DIM}  ── .gitignore Template ──────────────${C_RESET}"
  echo -e "  ${C_DIM}0${C_RESET} › Tidak  ${C_CYAN}1${C_RESET} › Node  ${C_CYAN}2${C_RESET} › Python  ${C_CYAN}3${C_RESET} › Java"
  echo -e "  ${C_CYAN}4${C_RESET} › Go     ${C_CYAN}5${C_RESET} › Ruby  ${C_CYAN}6${C_RESET} › C++     ${C_CYAN}7${C_RESET} › Rust"
  local gi_pick="" gi_template="" gi_label="Tidak"
  # .gitignore hanya bisa dipakai jika auto_init=true
  if [ "$auto_init" = false ]; then
    echo -e "  ${C_DIM}(dilewati — README harus aktif untuk gitignore)${C_RESET}"
    gi_label="N/A"
  else
    while true; do
      printf "  ${C_BOLD}▸ ${C_RESET}"
      read -r gi_pick
      gi_pick=$(echo "$gi_pick" | tr -d '\n\r ')
      case "$gi_pick" in
        0|"") gi_template="";       gi_label="Tidak";  break ;;
        1)    gi_template="Node";   gi_label="Node";   break ;;
        2)    gi_template="Python"; gi_label="Python"; break ;;
        3)    gi_template="Java";   gi_label="Java";   break ;;
        4)    gi_template="Go";     gi_label="Go";     break ;;
        5)    gi_template="Ruby";   gi_label="Ruby";   break ;;
        6)    gi_template="C++";    gi_label="C++";    break ;;
        7)    gi_template="Rust";   gi_label="Rust";   break ;;
        *) echo -e "  ${C_RED}✖ Pilih 0–7.${C_RESET}" ;;
      esac
    done
  fi
  echo ""

  # ── 6) License ──────────────────────────────────────────────────────────
  echo -e "${C_DIM}  ── License ──────────────────────────${C_RESET}"
  echo -e "  ${C_DIM}0${C_RESET} › Tidak  ${C_CYAN}1${C_RESET} › MIT  ${C_CYAN}2${C_RESET} › Apache-2.0"
  echo -e "  ${C_CYAN}3${C_RESET} › GPL-3.0  ${C_CYAN}4${C_RESET} › LGPL-2.1  ${C_CYAN}5${C_RESET} › AGPL-3.0"
  local lic_pick="" lic_template="" lic_label="Tidak"
  if [ "$auto_init" = false ]; then
    echo -e "  ${C_DIM}(dilewati — README harus aktif untuk license)${C_RESET}"
    lic_label="N/A"
  else
    while true; do
      printf "  ${C_BOLD}▸ ${C_RESET}"
      read -r lic_pick
      lic_pick=$(echo "$lic_pick" | tr -d '\n\r ')
      case "$lic_pick" in
        0|"") lic_template="";           lic_label="Tidak";    break ;;
        1)    lic_template="mit";        lic_label="MIT";      break ;;
        2)    lic_template="apache-2.0"; lic_label="Apache-2.0"; break ;;
        3)    lic_template="gpl-3.0";   lic_label="GPL-3.0";  break ;;
        4)    lic_template="lgpl-2.1";  lic_label="LGPL-2.1"; break ;;
        5)    lic_template="agpl-3.0";  lic_label="AGPL-3.0"; break ;;
        *) echo -e "  ${C_RED}✖ Pilih 0–5.${C_RESET}" ;;
      esac
    done
  fi
  echo ""

  # ── Ringkasan konfirmasi ────────────────────────────────────────────────
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   📦  KONFIRMASI BUAT REPO        │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_DIM}Nama        ${C_RESET}${C_BOLD}%s${C_RESET}\n" "$new_repo_name"
  if [ -n "$new_desc" ]; then
    printf "  ${C_DIM}Deskripsi   ${C_RESET}%s\n" "$new_desc"
  else
    printf "  ${C_DIM}Deskripsi   ${C_RESET}${C_DIM}(kosong)${C_RESET}\n"
  fi
  printf "  ${C_DIM}Visibilitas ${C_RESET}%s\n"  "$vis_label"
  printf "  ${C_DIM}README      ${C_RESET}%s\n"  "$readme_label"
  printf "  ${C_DIM}Gitignore   ${C_RESET}%s\n"  "$gi_label"
  printf "  ${C_DIM}License     ${C_RESET}%s\n"  "$lic_label"
  printf "  ${C_DIM}URL nanti   ${C_RESET}${C_CYAN}github.com/%s/%s${C_RESET}\n" "$USER" "$new_repo_name"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo ""
  echo -e "  ${C_GREEN}y${C_RESET} ${C_BOLD}›${C_RESET} Buat sekarang"
  echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Batal"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"
  local confirm
  read -r confirm
  confirm=$(echo "$confirm" | tr -d '\n\r ' | tr '[:upper:]' '[:lower:]')
  if [ "$confirm" != "y" ]; then
    echo -e "  ${C_YELLOW}⚠️  Dibatalkan.${C_RESET}"
    sleep 1
    return
  fi

  # ── Bangun JSON payload ─────────────────────────────────────────────────
  # Escape karakter JSON-sensitive (backslash dulu, lalu kutip ganda)
  local name_json desc_json
  name_json=$(printf '%s' "$new_repo_name" | sed 's/\\/\\\\/g;s/"/\\"/g')
  desc_json=$(printf '%s' "$new_desc"      | sed 's/\\/\\\\/g;s/"/\\"/g')
  local payload="{\"name\":\"${name_json}\",\"description\":\"${desc_json}\",\"private\":${is_private},\"auto_init\":${auto_init}"
  [ -n "$gi_template"  ] && payload="${payload},\"gitignore_template\":\"${gi_template}\""
  [ -n "$lic_template" ] && payload="${payload},\"license_template\":\"${lic_template}\""
  payload="${payload}}"

  # ── Kirim ke GitHub API ─────────────────────────────────────────────────
  echo ""
  echo -e "  ${C_DIM}▸ Membuat repository di GitHub...${C_RESET}"

  local resp http_code
  resp=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "https://api.github.com/user/repos" 2>/dev/null)

  http_code=$(printf '%s' "$resp" | tail -1)
  local body
  body=$(printf '%s' "$resp" | sed '$d')

  # ── Tampilkan hasil ─────────────────────────────────────────────────────
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   📦  BUAT REPOSITORY BARU       │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""

  if [ "$http_code" = "201" ]; then
    # Ekstrak info dari response
    local clone_url html_url full_name visibility
    clone_url=$(printf '%s' "$body" | grep -oE '"clone_url"[[:space:]]*:[[:space:]]*"[^"]*"' \
                | head -1 | sed 's/.*"clone_url"[[:space:]]*:[[:space:]]*"//;s/".*//')
    html_url=$(printf '%s' "$body" | grep -oE '"html_url"[[:space:]]*:[[:space:]]*"https://github.com/[^"]*"' \
               | head -1 | sed 's/.*"html_url"[[:space:]]*:[[:space:]]*"//;s/".*//')
    full_name=$(printf '%s' "$body" | grep -oE '"full_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
                | head -1 | sed 's/.*"full_name"[[:space:]]*:[[:space:]]*"//;s/".*//')

    echo -e "  ${C_GREEN}✅ Repository berhasil dibuat!${C_RESET}"
    echo ""
    echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
    printf "  ${C_DIM}Nama    ${C_RESET}${C_BOLD}%s${C_RESET}\n"       "${full_name:-${USER}/${new_repo_name}}"
    printf "  ${C_DIM}Visib.  ${C_RESET}%s\n"                           "$vis_label"
    printf "  ${C_DIM}URL     ${C_RESET}${C_CYAN}%s${C_RESET}\n"       "${html_url:-https://github.com/${USER}/${new_repo_name}}"
    printf "  ${C_DIM}Clone   ${C_RESET}${C_DIM}%s${C_RESET}\n"        "${clone_url:-https://github.com/${USER}/${new_repo_name}.git}"
    echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
    echo ""
    echo -e "  ${C_DIM}▸ Clone dengan:${C_RESET}"
    echo -e "  ${C_BOLD}git clone ${clone_url:-https://github.com/${USER}/${new_repo_name}.git}${C_RESET}"
  else
    # Ekstrak pesan error dari GitHub
    local err_msg
    err_msg=$(printf '%s' "$body" | grep -oE '"message"[[:space:]]*:[[:space:]]*"[^"]*"' \
              | head -1 | sed 's/.*"message"[[:space:]]*:[[:space:]]*"//;s/".*//')
    echo -e "  ${C_RED}❌ Gagal membuat repository (HTTP ${http_code})${C_RESET}"
    [ -n "$err_msg" ] && echo -e "  ${C_RED}   ${err_msg}${C_RESET}"
    echo ""
    if [ "$http_code" = "422" ]; then
      echo -e "  ${C_YELLOW}💡 Kemungkinan nama repo sudah dipakai.${C_RESET}"
    elif [ "$http_code" = "401" ]; then
      echo -e "  ${C_YELLOW}💡 Token tidak valid atau sudah expired.${C_RESET}"
    elif [ "$http_code" = "403" ]; then
      echo -e "  ${C_YELLOW}💡 Token tidak punya izin membuat repo.${C_RESET}"
      echo -e "  ${C_DIM}   Cek scope token: butuh 'repo' atau 'public_repo'.${C_RESET}"
    fi
  fi

  echo ""
  prompt_back_or_exit
}

# ===== Action: import repository dari URL eksternal =====
action_import_repo() {
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   📥  IMPORT REPOSITORY           │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "  ${C_DIM}Impor project dari Git URL ke GitHub.${C_RESET}"
  echo -e "  ${C_DIM}(Support: Git • SVN/TFVC tidak didukung lagi)${C_RESET}"
  echo ""

  # ── 1) Source URL ───────────────────────────────────────────────────────
  echo -e "${C_DIM}  ── URL Sumber ${C_RESET}${C_DIM}* wajib ─────────────────${C_RESET}"
  echo -e "  ${C_DIM}Contoh: https://github.com/user/repo.git${C_RESET}"
  echo -e "  ${C_DIM}        https://gitlab.com/user/repo.git${C_RESET}"
  local src_url=""
  while true; do
    printf "  ${C_BOLD}▸ ${C_RESET}"
    read -r src_url
    src_url=$(echo "$src_url" | tr -d '\n\r ')
    if [ -z "$src_url" ]; then
      echo -e "  ${C_RED}✖ URL tidak boleh kosong.${C_RESET}"
    elif ! echo "$src_url" | grep -qE '^https?://'; then
      echo -e "  ${C_RED}✖ URL harus diawali http:// atau https://${C_RESET}"
    else
      break
    fi
  done
  echo ""

  # ── 2) Username sumber (opsional) ───────────────────────────────────────
  echo -e "${C_DIM}  ── Username Sumber ${C_RESET}${C_DIM}(opsional, Enter = skip) ─${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"
  local src_user=""
  read -r src_user
  src_user=$(echo "$src_user" | tr -d '\n\r')
  echo ""

  # ── 3) Password / Token sumber (opsional) ───────────────────────────────
  local src_pass=""
  if [ -n "$src_user" ]; then
    echo -e "${C_DIM}  ── Password / Token Sumber ──────────${C_RESET}"
    echo -e "  ${C_DIM}(input tersembunyi)${C_RESET}"
    printf "  ${C_BOLD}▸ ${C_RESET}"
    read -rs src_pass
    src_pass=$(echo "$src_pass" | tr -d '\n\r')
    echo ""
    echo ""
  fi

  # ── 4) Nama repository baru ─────────────────────────────────────────────
  echo -e "${C_DIM}  ── Nama Repository Baru ${C_RESET}${C_DIM}* wajib ────────${C_RESET}"
  echo -e "  ${C_DIM}(hanya huruf, angka, - dan _)${C_RESET}"
  # Auto-suggest dari URL
  local url_guess
  url_guess=$(printf '%s' "$src_url" | sed 's|.*/||;s|\.git$||;s|[^a-zA-Z0-9._-]|-|g')
  [ -n "$url_guess" ] && echo -e "  ${C_DIM}Saran: ${url_guess}${C_RESET}"
  local imp_repo_name=""
  while true; do
    printf "  ${C_BOLD}▸ ${C_RESET}"
    read -r imp_repo_name
    imp_repo_name=$(echo "$imp_repo_name" | tr -d '\n\r')
    [ -z "$imp_repo_name" ] && [ -n "$url_guess" ] && imp_repo_name="$url_guess"
    if [ -z "$imp_repo_name" ]; then
      echo -e "  ${C_RED}✖ Nama tidak boleh kosong.${C_RESET}"
    elif echo "$imp_repo_name" | grep -qE '[^a-zA-Z0-9._-]'; then
      echo -e "  ${C_RED}✖ Karakter tidak valid (hanya huruf/angka/-/_).${C_RESET}"
    elif [ "${#imp_repo_name}" -gt 100 ]; then
      echo -e "  ${C_RED}✖ Nama terlalu panjang.${C_RESET}"
    else
      break
    fi
  done
  echo ""

  # ── 5) Visibilitas ──────────────────────────────────────────────────────
  echo -e "${C_DIM}  ── Visibilitas ──────────────────────${C_RESET}"
  echo -e "  ${C_GREEN}1${C_RESET} ${C_BOLD}›${C_RESET} Public   ${C_DIM}(semua bisa lihat)${C_RESET}"
  echo -e "  ${C_CYAN}2${C_RESET} ${C_BOLD}›${C_RESET} Private  ${C_DIM}(hanya kamu)${C_RESET}"
  local imp_vis_pick="" imp_private=false imp_vis_label="🌐 Public"
  while true; do
    printf "  ${C_BOLD}▸ ${C_RESET}"
    read -r imp_vis_pick
    imp_vis_pick=$(echo "$imp_vis_pick" | tr -d '\n\r ')
    case "$imp_vis_pick" in
      1|"") imp_private=false; imp_vis_label="🌐 Public";  break ;;
      2)    imp_private=true;  imp_vis_label="🔒 Private"; break ;;
      *) echo -e "  ${C_RED}✖ Ketik 1 atau 2.${C_RESET}" ;;
    esac
  done
  echo ""

  # ── Konfirmasi ──────────────────────────────────────────────────────────
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   📥  KONFIRMASI IMPORT           │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_DIM}Sumber      ${C_RESET}${C_CYAN}%s${C_RESET}\n"  "$src_url"
  if [ -n "$src_user" ]; then
    printf "  ${C_DIM}Username    ${C_RESET}%s\n"                   "$src_user"
    printf "  ${C_DIM}Password    ${C_RESET}${C_DIM}%s${C_RESET}\n" "(tersembunyi)"
  else
    printf "  ${C_DIM}Kredensial  ${C_RESET}${C_DIM}tidak dipakai${C_RESET}\n"
  fi
  printf "  ${C_DIM}Repo baru   ${C_RESET}${C_BOLD}%s/%s${C_RESET}\n" "$USER" "$imp_repo_name"
  printf "  ${C_DIM}Visibilitas ${C_RESET}%s\n"                        "$imp_vis_label"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo ""
  echo -e "  ${C_GREEN}y${C_RESET} ${C_BOLD}›${C_RESET} Mulai import"
  echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Batal"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"
  local imp_confirm
  read -r imp_confirm
  imp_confirm=$(echo "$imp_confirm" | tr -d '\n\r ' | tr '[:upper:]' '[:lower:]')
  if [ "$imp_confirm" != "y" ]; then
    echo -e "  ${C_YELLOW}⚠️  Dibatalkan.${C_RESET}"
    sleep 1; return
  fi

  # ── Langkah 1: Buat repo kosong dulu ────────────────────────────────────
  echo ""
  echo -e "  ${C_DIM}▸ [1/2] Membuat repository kosong...${C_RESET}"
  local create_resp create_code
  local name_esc
  name_esc=$(printf '%s' "$imp_repo_name" | sed 's/\\/\\\\/g;s/"/\\"/g')
  local create_payload="{\"name\":\"${name_esc}\",\"private\":${imp_private},\"auto_init\":false}"

  create_resp=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$create_payload" \
    "https://api.github.com/user/repos" 2>/dev/null)
  create_code=$(printf '%s' "$create_resp" | tail -1)
  local create_body
  create_body=$(printf '%s' "$create_resp" | sed '$d')

  if [ "$create_code" != "201" ]; then
    local cerr
    cerr=$(printf '%s' "$create_body" \
      | grep -oE '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
      | sed 's/.*"message"[[:space:]]*:[[:space:]]*"//;s/".*//')
    echo -e "  ${C_RED}❌ Gagal buat repo (HTTP ${create_code})${C_RESET}"
    [ -n "$cerr" ] && echo -e "  ${C_RED}   ${cerr}${C_RESET}"
    [ "$create_code" = "422" ] && \
      echo -e "  ${C_YELLOW}💡 Nama repo sudah dipakai di akun kamu.${C_RESET}"
    echo ""
    prompt_back_or_exit; return
  fi

  # ── Langkah 2: Mulai import ──────────────────────────────────────────────
  echo -e "  ${C_DIM}▸ [2/2] Memulai import dari sumber...${C_RESET}"

  # Bangun payload import
  local src_url_esc
  src_url_esc=$(printf '%s' "$src_url" | sed 's/\\/\\\\/g;s/"/\\"/g')
  local imp_payload="{\"vcs\":\"git\",\"vcs_url\":\"${src_url_esc}\""
  if [ -n "$src_user" ]; then
    local su_esc sp_esc
    su_esc=$(printf '%s' "$src_user" | sed 's/\\/\\\\/g;s/"/\\"/g')
    sp_esc=$(printf '%s' "$src_pass" | sed 's/\\/\\\\/g;s/"/\\"/g')
    imp_payload="${imp_payload},\"vcs_username\":\"${su_esc}\",\"vcs_password\":\"${sp_esc}\""
  fi
  imp_payload="${imp_payload}}"

  local imp_resp imp_code
  imp_resp=$(curl -s -w "\n%{http_code}" \
    -X PUT \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$imp_payload" \
    "https://api.github.com/repos/${USER}/${imp_repo_name}/import" 2>/dev/null)
  imp_code=$(printf '%s' "$imp_resp" | tail -1)
  local imp_body
  imp_body=$(printf '%s' "$imp_resp" | sed '$d')

  # ── Tampilkan status awal + polling ─────────────────────────────────────
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   📥  IMPORT REPOSITORY           │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""

  if [ "$imp_code" = "201" ]; then
    local imp_status imp_text
    imp_status=$(printf '%s' "$imp_body" \
      | grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
      | sed 's/.*"status"[[:space:]]*:[[:space:]]*"//;s/".*//')
    imp_text=$(printf '%s' "$imp_body" \
      | grep -oE '"status_text"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
      | sed 's/.*"status_text"[[:space:]]*:[[:space:]]*"//;s/".*//')

    echo -e "  ${C_GREEN}✅ Import dimulai!${C_RESET}"
    echo ""
    echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
    printf "  ${C_DIM}Repo     ${C_RESET}${C_BOLD}%s/%s${C_RESET}\n"  "$USER" "$imp_repo_name"
    printf "  ${C_DIM}Sumber   ${C_RESET}${C_CYAN}%s${C_RESET}\n"      "$src_url"
    printf "  ${C_DIM}Status   ${C_RESET}${C_YELLOW}%s${C_RESET}\n"    "${imp_status:-importing}"
    [ -n "$imp_text" ] && \
      printf "  ${C_DIM}Info     ${C_RESET}%s\n" "$imp_text"
    echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
    echo ""
    # ── Polling status sampai selesai atau error ─────────────────────────
    echo -e "  ${C_DIM}▸ Memantau progress import...${C_RESET}"
    echo -e "  ${C_DIM}  (Ctrl+C untuk berhenti pantau, import tetap berjalan)${C_RESET}"
    echo ""
    local poll_count=0 poll_max=30
    while [ "$poll_count" -lt "$poll_max" ]; do
      sleep 4
      poll_count=$(( poll_count + 1 ))
      local poll_raw poll_status poll_text poll_pct
      poll_raw=$(curl -s \
        -H "Authorization: token ${TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/${USER}/${imp_repo_name}/import" 2>/dev/null)
      poll_status=$(printf '%s' "$poll_raw" \
        | grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/.*"status"[[:space:]]*:[[:space:]]*"//;s/".*//')
      poll_text=$(printf '%s' "$poll_raw" \
        | grep -oE '"status_text"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/.*"status_text"[[:space:]]*:[[:space:]]*"//;s/".*//')
      poll_pct=$(printf '%s' "$poll_raw" \
        | grep -oE '"percent"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 \
        | grep -oE '[0-9]+$')

      # Tampilkan baris status
      local bar=""
      if [ -n "$poll_pct" ] && [ "$poll_pct" -ge 0 ] 2>/dev/null; then
        local filled=$(( poll_pct / 5 ))   # bar 20 karakter
        local empty=$(( 20 - filled ))
        bar="["
        for (( _i=0; _i<filled; _i++ )); do bar="${bar}█"; done
        for (( _i=0; _i<empty;  _i++ )); do bar="${bar}░"; done
        bar="${bar}] ${poll_pct}%"
      fi

      case "$poll_status" in
        complete)
          echo -e "  ${C_GREEN}✅ Import selesai!${C_RESET}"
          echo ""
          printf "  ${C_DIM}URL    ${C_RESET}${C_CYAN}https://github.com/%s/%s${C_RESET}\n" \
            "$USER" "$imp_repo_name"
          echo ""
          break
          ;;
        error|authentication_failed|error_stash_import)
          echo -e "  ${C_RED}❌ Import gagal: ${poll_status}${C_RESET}"
          [ -n "$poll_text" ] && echo -e "  ${C_RED}   ${poll_text}${C_RESET}"
          echo ""
          break
          ;;
        auth_failed)
          echo -e "  ${C_RED}❌ Autentikasi sumber gagal.${C_RESET}"
          echo -e "  ${C_YELLOW}💡 Coba lagi dengan username/password yang benar.${C_RESET}"
          echo ""
          break
          ;;
        *)
          # Masih berjalan — tampilkan satu baris progress
          local st_disp="${poll_status:-importing}"
          [ -n "$poll_text" ] && st_disp="$poll_text"
          if [ -n "$bar" ]; then
            printf "  ${C_CYAN}%s${C_RESET}  %s\n" "$bar" "$st_disp"
          else
            printf "  ${C_DIM}[%2d]${C_RESET} ${C_CYAN}%s${C_RESET}\n" "$poll_count" "$st_disp"
          fi
          ;;
      esac
    done
    if [ "$poll_count" -ge "$poll_max" ]; then
      echo -e "  ${C_YELLOW}⚠️  Import masih berjalan di background.${C_RESET}"
      printf "  ${C_DIM}Cek di  ${C_RESET}${C_CYAN}https://github.com/%s/%s${C_RESET}\n" \
        "$USER" "$imp_repo_name"
    fi
  else
    local ierr
    ierr=$(printf '%s' "$imp_body" \
      | grep -oE '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
      | sed 's/.*"message"[[:space:]]*:[[:space:]]*"//;s/".*//')
    echo -e "  ${C_RED}❌ Gagal memulai import (HTTP ${imp_code})${C_RESET}"
    [ -n "$ierr" ] && echo -e "  ${C_RED}   ${ierr}${C_RESET}"
    echo ""
    echo -e "  ${C_DIM}Repo ${USER}/${imp_repo_name} sudah dibuat tapi kosong.${C_RESET}"
    echo -e "  ${C_DIM}Kamu bisa hapus manual di GitHub atau coba import lagi.${C_RESET}"
  fi

  echo ""
  prompt_back_or_exit
}

# ===== Action: edit (rename) nama branch =====
action_rename_branch() {
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   ✏️   EDIT NAMA BRANCH          │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "  ${C_DIM}repo    ${C_RESET}${C_BOLD}${USER}/${REPO}${C_RESET}"
  echo ""

  # Ambil daftar branch dari GitHub
  local branches=()
  while IFS= read -r b; do
    [ -n "$b" ] && branches+=("$b")
  done < <(fetch_branches)

  local total=${#branches[@]}
  if [ "$total" -eq 0 ]; then
    echo -e "  ${C_YELLOW}ℹ️  Tidak ada branch yang ditemukan.${C_RESET}"
    prompt_back_or_exit
    return
  fi

  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  local i=1
  for b in "${branches[@]}"; do
    if [ "$b" = "$DEFAULT_BRANCH" ]; then
      printf "  ${C_GREEN}%2d${C_RESET} ${C_BOLD}›${C_RESET} %s  ${C_DIM}(default)${C_RESET}\n" "$i" "$b"
    else
      printf "  ${C_CYAN}%2d${C_RESET} ${C_BOLD}›${C_RESET} %s\n" "$i" "$b"
    fi
    i=$((i + 1))
  done
  echo -e "  ${C_RED} 0${C_RESET} ${C_BOLD}›${C_RESET} Kembali ke menu"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}Pilih branch ▸ ${C_RESET}"

  local pick
  read -r pick
  pick="${pick:-0}"

  if [ "$pick" = "0" ]; then
    echo -e "  ${C_YELLOW}↩ Kembali ke menu.${C_RESET}"
    sleep 1
    return
  fi

  if ! echo "$pick" | grep -qE '^[0-9]+$' || [ "$pick" -lt 1 ] || [ "$pick" -gt "$total" ]; then
    echo -e "  ${C_RED}✖ Pilihan tidak valid.${C_RESET}"
    sleep 2
    return
  fi

  local old_name="${branches[$((pick - 1))]}"

  # ── Layar 2: input nama baru ──────────────────────────────────────────
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   ✏️   EDIT NAMA BRANCH          │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "  ${C_DIM}branch dipilih  ${C_RESET}${C_BOLD}${old_name}${C_RESET}"
  echo ""
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Kembali ke menu"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}Nama baru ▸ ${C_RESET}"

  local new_name
  read -r new_name
  new_name=$(echo "$new_name" | tr -d '[:space:]')

  if [ -z "$new_name" ] || [ "$new_name" = "0" ]; then
    echo -e "  ${C_YELLOW}↩ Kembali ke menu.${C_RESET}"
    sleep 1
    return
  fi

  # Validasi nama branch
  if ! echo "$new_name" | grep -qE '^[a-zA-Z0-9._/-]+$'; then
    echo -e "  ${C_RED}✖ Nama tidak valid${C_RESET} ${C_DIM}(hanya huruf, angka, - _ / .)${C_RESET}"
    sleep 2
    return
  fi

  if [ "$new_name" = "$old_name" ]; then
    echo -e "  ${C_YELLOW}ℹ️  Nama sama seperti sekarang, tidak ada yang diubah.${C_RESET}"
    sleep 2
    return
  fi

  # ── Konfirmasi ────────────────────────────────────────────────────────
  echo ""
  echo -e "  ${C_RED}⚠️  Yakin rename branch?${C_RESET}"
  echo -e "  ${C_DIM}${old_name}${C_RESET} ${C_BOLD}→${C_RESET} ${C_GREEN}${new_name}${C_RESET}"
  echo ""
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo -e "  ${C_GREEN}1${C_RESET} ${C_BOLD}›${C_RESET} Lanjut rename"
  echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Batal"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"

  local confirm
  read -r confirm
  if [ "$confirm" != "1" ]; then
    echo -e "  ${C_YELLOW}↩ Dibatalkan.${C_RESET}"
    sleep 1
    return
  fi

  # ── Panggil GitHub API: POST /repos/{owner}/{repo}/branches/{branch}/rename ──
  echo ""
  echo -e "  ${C_CYAN}▸${C_RESET} Menghubungi GitHub API untuk rename branch..."

  local api_http
  api_http=$(curl -s -o /tmp/_gh_renbranch.json -w "%{http_code}" \
    -X POST \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${USER}/${REPO}/branches/${old_name}/rename" \
    -d "{\"new_name\":\"${new_name}\"}" 2>/dev/null)

  if [ "$api_http" = "201" ]; then
    echo ""
    echo -e "  ${C_GREEN}✅ Branch berhasil di-rename di GitHub!${C_RESET}"
    echo -e "  ${C_DIM}${old_name}${C_RESET} ${C_BOLD}→${C_RESET} ${C_GREEN}${new_name}${C_RESET}"
    echo -e "  ${C_BLUE}🔗 https://github.com/${USER}/${REPO}/tree/${new_name}${C_RESET}"

    # Kalau yang di-rename adalah default branch, update variabel & script
    if [ "$old_name" = "$DEFAULT_BRANCH" ]; then
      DEFAULT_BRANCH="$new_name"
      sed -i "s|^DEFAULT_BRANCH=.*|DEFAULT_BRANCH=\"${new_name}\"|" "$0" 2>/dev/null || true
      echo -e "  ${C_DIM}Default branch ikut diperbarui → ${C_GREEN}${new_name}${C_RESET}"
    fi
  else
    local api_msg
    api_msg=$(grep -o '"message": *"[^"]*"' /tmp/_gh_renbranch.json 2>/dev/null \
      | head -1 | sed 's/"message": *"//;s/"//')
    echo ""
    echo -e "  ${C_RED}❌ Gagal rename branch (HTTP ${api_http})${C_RESET}"
    [ -n "$api_msg" ] && echo -e "  ${C_DIM}   GitHub: ${api_msg}${C_RESET}"
    echo -e "  ${C_DIM}   Pastikan token punya scope: repo (full control)${C_RESET}"
  fi

  rm -f /tmp/_gh_renbranch.json
  prompt_back_or_exit
}

# ===== Action: buat branch baru =====
action_create_branch() {
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   🌱  BUAT BRANCH BARU           │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Kembali ke menu"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}Nama branch baru ▸ ${C_RESET}"
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
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   🗑️   HAPUS BRANCH              │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "  ${C_DIM}default dilindungi: ${C_RESET}${C_GREEN}${DEFAULT_BRANCH}${C_RESET}"
  echo ""

  local branches=()
  while IFS= read -r b; do
    [ -n "$b" ] && [ "$b" != "$DEFAULT_BRANCH" ] && branches+=("$b")
  done < <(fetch_branches)

  local total=${#branches[@]}
  if [ "$total" -eq 0 ]; then
    echo -e "  ${C_YELLOW}ℹ️  Tidak ada branch yang bisa dihapus${C_RESET}"
    echo -e "  ${C_DIM}   (hanya branch default '${DEFAULT_BRANCH}' yang ada)${C_RESET}"
    prompt_back_or_exit
    return
  fi

  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  local i=1
  for b in "${branches[@]}"; do
    printf "  ${C_YELLOW}%2d${C_RESET} ${C_BOLD}›${C_RESET} %s\n" "$i" "$b"
    i=$((i + 1))
  done
  echo -e "  ${C_RED} 0${C_RESET} ${C_BOLD}›${C_RESET} Kembali ke menu"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo -e "  ${C_DIM}multi-hapus: pisahkan dengan koma/spasi  •  ${C_BOLD}all${C_RESET}${C_DIM} = semua${C_RESET}"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"

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
  echo -e "  ${C_RED}⚠️  Yakin hapus ${#targets[@]} branch dari lokal & remote?${C_RESET}"
  for t in "${targets[@]}"; do
    echo -e "     ${C_YELLOW}›${C_RESET} ${C_BOLD}${t}${C_RESET}"
  done
  echo ""
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo -e "  ${C_GREEN}1${C_RESET} ${C_BOLD}›${C_RESET} Lanjut hapus"
  echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Batal"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"
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
  echo -e "${C_DIM}  ── Ringkasan ──────────────────────${C_RESET}"
  echo -e "  ${C_GREEN}✅ Sukses : ${ok}${C_RESET}"
  [ "$fail" -gt 0 ] && echo -e "  ${C_RED}❌ Gagal  : ${fail}${C_RESET}"

  prompt_back_or_exit
}

# ===== Menu pemilih branch (sub-menu dari opsi 1) =====
show_menu() {
  clear >/dev/tty 2>/dev/null || true
  echo -e "${C_BOLD}╭──────────────────────────────────╮${C_RESET}"
  echo -e "${C_BOLD}│   📤  UPLOAD — PILIH BRANCH      │${C_RESET}"
  echo -e "${C_BOLD}╰──────────────────────────────────╯${C_RESET}"
  echo ""
  echo -e "  ${C_DIM}repo  ${C_RESET}${C_BOLD}${USER}/${REPO}${C_RESET}"
  echo ""

  local branches=()
  while IFS= read -r b; do
    [ -n "$b" ] && branches+=("$b")
  done < <(fetch_branches)

  local total=${#branches[@]}

  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  local i=1
  for b in "${branches[@]}"; do
    if [ "$b" = "$DEFAULT_BRANCH" ]; then
      printf "  ${C_GREEN}%2d${C_RESET} ${C_BOLD}›${C_RESET} %s  ${C_DIM}(default)${C_RESET}\n" "$i" "$b"
    else
      printf "  ${C_CYAN}%2d${C_RESET} ${C_BOLD}›${C_RESET} %s\n" "$i" "$b"
    fi
    i=$((i + 1))
  done
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo -e "  ${C_YELLOW} A${C_RESET} ${C_BOLD}›${C_RESET} Semua branch"
  echo -e "  ${C_GREEN} D${C_RESET} ${C_BOLD}›${C_RESET} Default  ${C_DIM}(${DEFAULT_BRANCH})${C_RESET}"
  echo -e "  ${C_RED} 0${C_RESET} ${C_BOLD}›${C_RESET} Kembali"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"

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
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo -e "  ${C_GREEN}1${C_RESET} ${C_BOLD}›${C_RESET} Kembali ke menu"
  echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Keluar"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"
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
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  echo -e "  ${C_GREEN}1${C_RESET} ${C_BOLD}›${C_RESET} Kembali ke menu"
  echo -e "  ${C_RED}0${C_RESET} ${C_BOLD}›${C_RESET} Keluar"
  echo -e "${C_DIM}  ──────────────────────────────────${C_RESET}"
  printf "  ${C_BOLD}▸ ${C_RESET}"
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