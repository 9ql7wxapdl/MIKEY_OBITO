#!/usr/bin/env bash
# Push Script — Bang Wily | Auto Commit + Multi-Branch
# Usage: bash push.sh [pesan commit custom]

USER="hitlabmodv2"
REPO="ReadswDika-V13"
DEFAULT_BRANCH="main"
IGNORE_BRANCHES="replit-agent HEAD"

set -o pipefail

if [ -t 1 ]; then
  R="\033[0m"; DIM="\033[2m"; B="\033[1m"
  G="\033[32m"; RED="\033[31m"; Y="\033[33m"
  C="\033[36m"; BL="\033[34m"; M="\033[35m"
else
  R=""; DIM=""; B=""; G=""; RED=""; Y=""; C=""; BL=""; M=""
fi

CUSTOM_MSG="${1:-}"

if [ ! -f .token ]; then
  echo -e "${RED}❌ File .token tidak ada!${R}"
  echo "   Bikin dulu : echo 'ghp_xxxxxxxx' > .token"
  exit 1
fi
TOKEN=$(tr -d '\n\r ' < .token)
if [ -z "$TOKEN" ]; then
  echo -e "${RED}❌ File .token kosong!${R}"
  exit 1
fi

REMOTE_URL="https://${USER}:${TOKEN}@github.com/${USER}/${REPO}.git"

[ -d .git ] || git init -q
git config user.name "$USER"
git config user.email "${USER}@users.noreply.github.com"
git config checkout.defaultRemote origin

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE_URL"
else
  git remote add origin "$REMOTE_URL"
fi

classify_commit() {
  local files status_lines
  status_lines=$(git diff --cached --name-status)
  files=$(echo "$status_lines" | awk '{print $2}')

  local added modified deleted
  added=$(echo "$status_lines"    | awk '$1=="A"' | wc -l | tr -d ' ')
  modified=$(echo "$status_lines" | awk '$1=="M"' | wc -l | tr -d ' ')
  deleted=$(echo "$status_lines"  | awk '$1=="D"' | wc -l | tr -d ' ')

  local scope="" scope_count=0
  declare -A scope_map=(
    [src/scrape/]="scrape" [src/handler/]="handler"
    [src/helper/]="helper" [src/db/]="db"
    [src/lib/]="lib"       [data/]="data"
    [sessions/]="session"  [attached_assets/]="assets"
    [.agents/]="agents"    [jadibot/]="jadibot"
  )
  for prefix in "${!scope_map[@]}"; do
    local cnt; cnt=$(echo "$files" | grep -c "^${prefix}" || true)
    if [ "$cnt" -gt "$scope_count" ]; then scope_count=$cnt; scope="${scope_map[$prefix]}"; fi
  done

  echo "$files" | grep -qE '^(package\.json|package-lock\.json)$' && [ -z "$scope" ] && scope="deps"
  echo "$files" | grep -qE '^(\.gitignore|push\.sh|index\.js|config\.json|Dockerfile)$' && [ -z "$scope" ] && scope="config"

  local type
  if echo "$files" | grep -qE '^(package\.json|package-lock\.json)$' && [ "$scope_count" -le 1 ]; then
    type="deps"
  elif [ "$added" -ge "$modified" ] && [ "$added" -gt 0 ] && echo "$files" | grep -qE '^src/(scrape|handler|helper|lib)/'; then
    type="feat"
  elif [ "$scope" = "data" ] || [ "$scope" = "session" ] || [ "$scope" = "config" ] || [ "$scope" = "assets" ]; then
    type="chore"
  elif [ "$modified" -gt 0 ] && echo "$files" | grep -qE '^src/'; then
    type="fix"
  else
    type="chore"
  fi

  local total sample
  total=$(echo "$files" | wc -l | tr -d ' ')
  sample=$(echo "$files" | head -3 | xargs -n1 basename 2>/dev/null | tr '\n' ', ' | sed 's/, $//')
  [ "$total" -gt 3 ] && sample="$sample +$((total - 3)) file lain"

  [ -n "$scope" ] && echo "${type}(${scope}): ${sample}" || echo "${type}: ${sample}"
}

prepare_stage() {
  local lock=".git/index.lock"
  if [ -f "$lock" ]; then
    local now mtime age
    now=$(date +%s)
    mtime=$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null || echo "$now")
    age=$((now - mtime))
    [ "$age" -gt 30 ] && rm -f "$lock"
  fi

  local err; err=$(mktemp)

  git ls-files 2>/dev/null | grep -E '^sessions/hisoka/' | while read -r f; do
    case "$f" in
      sessions/hisoka/creds.json|sessions/hisoka/contacts.json|sessions/hisoka/groups.json|\
      sessions/hisoka/auth.db|sessions/hisoka/auth.db-shm|sessions/hisoka/auth.db-wal) ;;
      *) git rm --cached -q "$f" 2>>"$err" || true ;;
    esac
  done

  git add -A 2>>"$err" || { echo -e "  ${RED}❌ git add gagal${R}"; rm -f "$err"; return 1; }

  for f in package-lock.json .env sessions/hisoka/creds.json sessions/hisoka/contacts.json \
            sessions/hisoka/groups.json sessions/hisoka/auth.db sessions/hisoka/auth.db-shm \
            sessions/hisoka/auth.db-wal attached_assets .agents .replit node_modules; do
    [ -e "$f" ] && git add -f "$f" 2>>"$err" || true
  done

  rm -f "$err"
  return 0
}

fetch_branches() {
  git fetch origin --quiet 2>/dev/null || true
  local pat=""
  for b in $IGNORE_BRANCHES; do
    [ -z "$pat" ] && pat="^${b}$" || pat="${pat}|^${b}$"
  done
  [ -z "$pat" ] && pat="^$"
  {
    git for-each-ref --format='%(refname)' refs/heads/ 2>/dev/null | sed 's|^refs/heads/||'
    git ls-remote --heads origin 2>/dev/null | awk '{print $2}' | sed 's|^refs/heads/||'
  } | grep -v '^$' | grep -Ev "$pat" | sort -u
}

banner() {
  clear 2>/dev/null || true
  echo -e "${B}🚀 PUSH SCRIPT — BANG WILY${R}"
  echo -e "${DIM}Auto Commit • Multi-Branch • ${USER}/${REPO}${R}"
  echo -e "${DIM}Default branch:${R} ${G}${DEFAULT_BRANCH}${R}"
  echo ""
}

commit_pending_changes() {
  COMMIT_DONE="no"

  local pre; pre=$(git status --porcelain --untracked-files=all 2>/dev/null)
  local pre_total; pre_total=$(echo "$pre" | grep -c . || true)

  echo -e "${B}🔍 Scan${R} ${DIM}(branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null))${R}"
  [ "$pre_total" -gt 0 ] \
    && echo -e "  ${C}▸${R} ${B}${pre_total}${R} file berubah" \
    || echo -e "  ${DIM}▸ 0 perubahan${R}"

  prepare_stage || { echo -e "  ${RED}❌ Gagal stage${R}"; return 1; }

  if ! git diff --cached --quiet 2>/dev/null; then
    local staged; staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    local MSG
    [ -n "$CUSTOM_MSG" ] && MSG="$CUSTOM_MSG" || MSG=$(classify_commit)

    git commit -q -m "$MSG" 2>/dev/null || { echo -e "  ${RED}❌ Commit gagal${R}"; return 1; }
    echo -e "  ${G}✅${R} ${MSG}"
    COMMIT_DONE="yes"
  fi

  HEAD_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
  return 0
}

push_head_to_branch() {
  local branch="$1"
  echo ""
  echo -e "${B}${USER}/${REPO} → ${G}${branch}${R}${B} (HEAD ${HEAD_SHA})${R}"

  git fetch origin "$branch" --quiet 2>/dev/null || true
  if git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
    local l; l=$(git rev-parse HEAD 2>/dev/null)
    local r; r=$(git rev-parse "refs/remotes/origin/${branch}" 2>/dev/null)
    if [ "$l" = "$r" ] && [ "$COMMIT_DONE" = "no" ]; then
      echo -e "  ${G}✅ Sudah up-to-date${R} → ${BL}https://github.com/${USER}/${REPO}/tree/${branch}${R}"
      return 0
    fi
  fi

  local log; log=$(mktemp)
  if git push origin "HEAD:refs/heads/${branch}" >"$log" 2>&1; then
    rm -f "$log"
    echo -e "  ${G}🎉 Sukses!${R} ${BL}https://github.com/${USER}/${REPO}/tree/${branch}${R}"
    return 0
  fi

  echo -e "  ${Y}⚠️  Normal push gagal, force push...${R}"
  if git push --force origin "HEAD:refs/heads/${branch}" >"$log" 2>&1; then
    rm -f "$log"
    echo -e "  ${G}🎉 Sukses (force)!${R} ${BL}https://github.com/${USER}/${REPO}/tree/${branch}${R}"
    return 0
  fi

  echo -e "  ${RED}❌ Gagal push ke ${branch}${R}"
  sed 's/^/    /' "$log" | tail -8
  rm -f "$log"
  return 1
}

run_upload() {
  local count=${#SELECTED_BRANCHES[@]} ok=0 fail=0
  [ "$count" -gt 1 ] && echo -e "\n${M}▶ Multi-branch (${count} tujuan)${R}"
  echo ""

  commit_pending_changes || { echo -e "${RED}❌ Batal push.${R}"; return 1; }

  for b in "${SELECTED_BRANCHES[@]}"; do
    push_head_to_branch "$b" && ok=$((ok+1)) || fail=$((fail+1))
  done

  if [ "$count" -gt 1 ]; then
    echo -e "\n${B}─── Ringkasan ───${R}"
    echo -e "  ${G}✅ Sukses : ${ok}${R}"
    [ "$fail" -gt 0 ] && echo -e "  ${RED}❌ Gagal  : ${fail}${R}"
  fi
}

show_menu() {
  banner
  local branches=()
  while IFS= read -r b; do [ -n "$b" ] && branches+=("$b"); done < <(fetch_branches)
  local total=${#branches[@]}

  echo -e "${B}Pilih branch tujuan${R} ${DIM}(total ${total})${R}"
  local i=1
  for b in "${branches[@]}"; do
    [ "$b" = "$DEFAULT_BRANCH" ] \
      && printf "  ${G}%2d${R} %s ${DIM}(default)${R}\n" "$i" "$b" \
      || printf "  ${C}%2d${R} %s\n" "$i" "$b"
    i=$((i+1))
  done

  echo ""
  echo -e "  ${Y} A${R} semua branch"
  echo -e "  ${G} D${R} default (${DEFAULT_BRANCH})"
  echo -e "  ${RED} 0${R} kembali"
  echo ""
  printf "${B}Pilihan ▸ ${R}"
  local choice; read -r choice; choice="${choice:-D}"

  case "$choice" in
    0|q|Q) goodbye_prompt ;;
    a|A)   SELECTED_BRANCHES=("${branches[@]}") ;;
    d|D|"") SELECTED_BRANCHES=("$DEFAULT_BRANCH") ;;
    *[!0-9]*)
      echo -e "${RED}✖ Tidak valid${R}"; sleep 1; show_menu ;;
    *)
      if [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
        SELECTED_BRANCHES=("${branches[$((choice-1))]}")
      else
        echo -e "${RED}✖ Di luar range (1-${total})${R}"; sleep 1; show_menu
      fi ;;
  esac
}

action_create_branch() {
  banner
  echo -e "${B}🌱 Buat branch baru${R}"
  echo ""
  printf "${B}Nama branch (0=batal) ▸ ${R}"
  local name; read -r name
  name=$(echo "$name" | tr -d '[:space:]')

  [ -z "$name" ] || [ "$name" = "0" ] && { echo -e "${Y}↩ Batal.${R}"; sleep 1; return; }
  ! echo "$name" | grep -qE '^[a-zA-Z0-9._/-]+$' && { echo -e "${RED}✖ Nama tidak valid${R}"; sleep 2; return; }

  if git show-ref --verify --quiet "refs/heads/${name}" \
     || git ls-remote --heads origin "$name" 2>/dev/null | grep -q .; then
    echo -e "${RED}✖ Branch '${name}' sudah ada.${R}"; sleep 2; return
  fi

  git checkout -q "$DEFAULT_BRANCH" 2>/dev/null || { echo -e "${RED}✖ Gagal pindah ke ${DEFAULT_BRANCH}${R}"; sleep 2; return; }
  git checkout -q -b "$name" 2>/dev/null || { echo -e "${RED}✖ Gagal bikin branch${R}"; sleep 2; return; }

  local log; log=$(mktemp)
  if git push -u origin "$name" >"$log" 2>&1; then
    echo -e "  ${G}🎉 Branch '${name}' berhasil!${R}"
    echo -e "  ${BL}https://github.com/${USER}/${REPO}/tree/${name}${R}"
  else
    echo -e "  ${RED}❌ Gagal push${R}"; sed 's/^/    /' "$log" | tail -8
  fi
  rm -f "$log"
  git checkout -q "$DEFAULT_BRANCH" 2>/dev/null || true
  echo ""; printf "${B}Enter untuk lanjut ▸ ${R}"; read -r
}

action_delete_branch() {
  banner
  echo -e "${B}🗑️  Hapus branch${R} ${DIM}(default '${DEFAULT_BRANCH}' dilindungi)${R}"
  echo ""

  local branches=()
  while IFS= read -r b; do
    [ -n "$b" ] && [ "$b" != "$DEFAULT_BRANCH" ] && branches+=("$b")
  done < <(fetch_branches)

  local total=${#branches[@]}
  if [ "$total" -eq 0 ]; then
    echo -e "${Y}ℹ️  Tidak ada branch yang bisa dihapus${R}"
    echo ""; printf "${B}Enter ▸ ${R}"; read -r; return
  fi

  local i=1
  for b in "${branches[@]}"; do printf "  ${Y}%2d${R} %s\n" "$i" "$b"; i=$((i+1)); done
  echo ""
  echo -e "  ${DIM}Pisah dengan koma/spasi. 'all' = semua${R}"
  echo -e "  ${RED} 0${R} kembali"
  echo ""
  printf "${B}Pilih ▸ ${R}"
  local pick; read -r pick; pick="${pick:-0}"

  [ "$pick" = "0" ] && { echo -e "${Y}↩ Batal.${R}"; sleep 1; return; }

  local targets=()
  if [ "$pick" = "all" ] || [ "$pick" = "ALL" ] || [ "$pick" = "a" ] || [ "$pick" = "A" ]; then
    targets=("${branches[@]}")
  else
    local norm; norm=$(echo "$pick" | tr ',;' '  ')
    local seen=" "
    for n in $norm; do
      if echo "$n" | grep -qE '^[0-9]+$' && [ "$n" -ge 1 ] && [ "$n" -le "$total" ]; then
        case "$seen" in *" $n "*) ;; *) targets+=("${branches[$((n-1))]}"); seen="$seen$n " ;; esac
      fi
    done
  fi

  [ ${#targets[@]} -eq 0 ] && { echo -e "${RED}✖ Tidak ada pilihan valid.${R}"; sleep 2; return; }

  echo -e "\n${RED}⚠️  Hapus ${#targets[@]} branch?${R}"
  for t in "${targets[@]}"; do echo -e "  ${Y}•${R} ${B}${t}${R}"; done
  echo ""
  printf "${B}Konfirmasi (1=lanjut / 0=batal) ▸ ${R}"
  local confirm; read -r confirm
  [ "$confirm" != "1" ] && { echo -e "${Y}↩ Dibatalkan.${R}"; sleep 1; return; }

  git checkout -q "$DEFAULT_BRANCH" 2>/dev/null || true
  local ok=0 fail=0
  for t in "${targets[@]}"; do
    [ "$t" = "$DEFAULT_BRANCH" ] && { echo -e "  ${RED}✖ '${t}' branch default — skip${R}"; fail=$((fail+1)); continue; }
    echo -e "\n${B}🗑️  ${t}${R}"
    git branch -D "$t" 2>/dev/null && echo -e "  ${G}✅ lokal${R}" || echo -e "  ${DIM}ℹ️  lokal tidak ada${R}"
    local log; log=$(mktemp)
    git push origin --delete "$t" >"$log" 2>&1 \
      && { echo -e "  ${G}✅ remote${R}"; ok=$((ok+1)); } \
      || { echo -e "  ${RED}❌ remote gagal${R}"; sed 's/^/    /' "$log" | tail -5; fail=$((fail+1)); }
    rm -f "$log"
  done

  echo -e "\n${B}─── Ringkasan ───${R}"
  echo -e "  ${G}✅ Sukses : ${ok}${R}"
  [ "$fail" -gt 0 ] && echo -e "  ${RED}❌ Gagal  : ${fail}${R}"
  echo ""; printf "${B}Enter ▸ ${R}"; read -r
}

show_main_menu() {
  banner
  echo -e "  ${G}1${R} upload (pilih branch)"
  echo -e "  ${C}2${R} buat branch baru"
  echo -e "  ${Y}3${R} hapus branch"
  echo -e "  ${RED}0${R} keluar"
  echo ""
  printf "${B}Pilih [0-3] ▸ ${R}"
  local pick; read -r pick; pick="${pick:-1}"

  case "$pick" in
    1) show_menu; run_upload ;;
    2) action_create_branch ;;
    3) action_delete_branch ;;
    0|q|Q) goodbye_prompt ;;
    *) echo -e "${RED}✖ Tidak valid${R}"; sleep 1 ;;
  esac
}

goodbye_prompt() {
  echo ""
  echo -e "${DIM}─────────────${R}"
  echo -e "  ${G}1${R} kembali ke menu"
  echo -e "  ${RED}0${R} keluar"
  printf "${B}▸ ${R}"
  local b; read -r b; b="${b:-1}"
  case "$b" in
    1|y|Y|m|M|menu) main_loop ;;
    *) echo -e "${DIM}Bye 👋${R}"; exit 0 ;;
  esac
}

on_interrupt() { echo ""; echo -e "${Y}⚠️  Ctrl+C${R}"; goodbye_prompt; }
trap on_interrupt INT

main_loop() {
  while true; do
    SELECTED_BRANCHES=()
    show_main_menu
    echo ""
    printf "${B}▸ ${R}"
    local next; read -r next; next="${next:-1}"
    case "$next" in q|Q|0) goodbye_prompt ;; esac
  done
}

main_loop
