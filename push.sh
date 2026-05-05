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
REPO="ReadswDika-V13"
# DEFAULT_BRANCH di-auto-detect realtime dari GitHub (lihat detect_default_branch).
# Nilai di sini cuma fallback kalau koneksi ke GitHub bermasalah.
DEFAULT_BRANCH="main"

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

# ===== Baca token =====
if [ ! -f .token ]; then
  echo -e "${C_RED}❌ File .token tidak ada!${C_RESET}"
  echo "   Bikin dulu : ${C_DIM}echo 'ghp_xxxxxxxx' > .token${C_RESET}"
  exit 1
fi
TOKEN=$(tr -d '\n\r ' < .token)
if [ -z "$TOKEN" ]; then
  echo -e "${C_RED}❌ File .token kosong!${C_RESET}"
  exit 1
fi

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
      sessions/hisoka/creds.json|sessions/hisoka/contacts.json|sessions/hisoka/groups.json|\
      sessions/hisoka/auth.db|sessions/hisoka/auth.db-shm|sessions/hisoka/auth.db-wal) ;;
      *) git rm --cached -q "$f" 2>>"$err_log" || true ;;
    esac
  done

  # Stage SEMUA perubahan (baru, modified, deleted, rename).
  if ! git add -A 2>>"$err_log"; then
    echo -e "  ${C_RED}❌ git add -A gagal${C_RESET}"
    sed 's/^/    /' "$err_log" | tail -10
    rm -f "$err_log"
    return 1
  fi

  # Force-add file penting yang biasanya di-ignore.
  for forced in package-lock.json .env \
                sessions/hisoka/creds.json \
                sessions/hisoka/contacts.json \
                sessions/hisoka/groups.json \
                sessions/hisoka/auth.db \
                sessions/hisoka/auth.db-shm \
                sessions/hisoka/auth.db-wal \
                attached_assets .agents \
                .replit node_modules; do
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

# ===== Ambil daftar branch (lokal + remote origin) =====
fetch_branches() {
  git fetch origin --quiet 2>/dev/null || true

  # Bangun pola ignore (regex) dari IGNORE_BRANCHES
  local ignore_pattern=""
  for b in $IGNORE_BRANCHES; do
    [ -z "$ignore_pattern" ] && ignore_pattern="^${b}$" || ignore_pattern="${ignore_pattern}|^${b}$"
  done
  [ -z "$ignore_pattern" ] && ignore_pattern="^$"

  {
    # Branch lokal — full refname biar nggak ke-resolve symbolic ref
    git for-each-ref --format='%(refname)' refs/heads/ 2>/dev/null \
      | sed 's|^refs/heads/||'

    # Branch remote di origin — pakai ls-remote biar bersih, tanpa HEAD
    git ls-remote --heads origin 2>/dev/null \
      | awk '{print $2}' | sed 's|^refs/heads/||'
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
  echo -e "  ${C_RED}0${C_RESET} keluar"
  echo ""
  printf "${C_BOLD}Pilih [0/1/2/3] ▸ ${C_RESET}"

  local pick
  read -r pick
  pick="${pick:-1}"

  case "$pick" in
    1) show_menu; run_upload ;;
    2) action_create_branch ;;
    3) action_delete_branch ;;
    0|q|Q|exit) goodbye_prompt ;;
    *)
      echo -e "${C_RED}✖ Pilihan tidak valid: '${pick}'${C_RESET}"
      sleep 1
      ;;
  esac
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

  # Cek apakah branch sudah ada (lokal atau remote)
  if git show-ref --verify --quiet "refs/heads/${name}" \
     || git ls-remote --heads origin "$name" 2>/dev/null | grep -q .; then
    echo -e "${C_RED}✖ Branch '${name}' sudah ada.${C_RESET}"
    sleep 2
    return
  fi

  echo ""
  echo -e "  ${C_CYAN}▸${C_RESET} bikin branch ${C_BOLD}${name}${C_RESET} dari ${DEFAULT_BRANCH}..."
  if ! git checkout -q "$DEFAULT_BRANCH" 2>/dev/null; then
    echo -e "${C_RED}✖ Gagal pindah ke ${DEFAULT_BRANCH}${C_RESET}"
    sleep 2
    return
  fi
  if ! git checkout -q -b "$name" 2>/dev/null; then
    echo -e "${C_RED}✖ Gagal bikin branch lokal${C_RESET}"
    sleep 2
    return
  fi

  echo -e "  ${C_CYAN}▸${C_RESET} push ke remote..."
  local push_log
  push_log=$(mktemp)
  if git push -u origin "$name" >"$push_log" 2>&1; then
    echo ""
    echo -e "  ${C_GREEN}🎉 Branch '${name}' berhasil dibuat & dipush!${C_RESET}"
    echo -e "  ${C_BLUE}🔗 https://github.com/${USER}/${REPO}/tree/${name}${C_RESET}"
  else
    echo -e "  ${C_RED}❌ Gagal push branch baru${C_RESET}"
    echo -e "  ${C_DIM}── error log ──${C_RESET}"
    sed 's/^/    /' "$push_log" | tail -10
  fi
  rm -f "$push_log"

  # Balik ke default
  git checkout -q "$DEFAULT_BRANCH" 2>/dev/null || true

  echo ""
  echo -e "  ${C_GREEN}1${C_RESET} ${C_DIM}kembali ke menu${C_RESET}"
  printf "${C_BOLD}▸ ${C_RESET}"
  read -r
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
    echo ""
    echo -e "  ${C_GREEN}1${C_RESET} ${C_DIM}kembali ke menu${C_RESET}"
    printf "${C_BOLD}▸ ${C_RESET}"
    read -r
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

  echo ""
  echo -e "  ${C_GREEN}1${C_RESET} ${C_DIM}kembali ke menu${C_RESET}"
  printf "${C_BOLD}▸ ${C_RESET}"
  read -r
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

  echo -e "  ${C_RED}❌ Gagal push ke ${branch}${C_RESET}"
  echo -e "  ${C_DIM}── error log ──${C_RESET}"
  sed 's/^/    /' "$push_log" | tail -10
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
}

# ===== Loop menu utama =====
main_loop() {
  while true; do
    SELECTED_BRANCHES=()
    show_main_menu

    echo ""
    echo -e "  ${C_GREEN}1${C_RESET} ${C_DIM}kembali ke menu${C_RESET}"
    echo -e "  ${C_RED}0${C_RESET} ${C_DIM}atau q untuk keluar${C_RESET}"
    printf "${C_BOLD}▸ ${C_RESET}"
    read -r next
    next="${next:-1}"
    case "$next" in
      q|Q|exit|0)
        goodbye_prompt
        ;;
    esac
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