#!/bin/bash
# publish.sh — everything after downloading a new PZ Backup version, so the only
# thing left is clicking "Update" in the game's Workshop screen.
#
# Usage: bash tools/publish.sh [options]
#        (works from anywhere, e.g. bash ~/Downloads/publish.sh the first time)
#
#   --repo DIR      local git repository          (default: ~/Projetos/PZBackup)
#   --patch FILE    patch to apply   (default: newest ~/Downloads/PZBackup-v*.patch)
#   --zip FILE      release zip      (default: ~/Downloads/PZBackup-vX.Y.Z.zip)
#   --private       keep the Workshop item private (default: public)
#   --no-release    don't create the GitHub release
#   --yes           don't ask for confirmation before pushing
#
# Steps:
#   1. finds the patch (and the release zip) in ~/Downloads
#   2. checks the repository: clean, on its branch, up to date with Forgejo
#   3. applies the patch. If your last commit is an older delivery of the same
#      version: replaces it when not pushed yet, or adds an update commit on top
#      when already pushed (history is never rewritten after a push)
#   4. checks the version is the same in every file
#   5. pushes the commit and the vX.Y.Z tag to Forgejo (which mirrors to GitHub)
#   6. GitHub release vX.Y.Z with the zip and the CHANGELOG notes (needs `gh`)
#   7. installs the new pz-backup.sh in your Zomboid folder (not the mod: the
#      Workshop delivers it)
#   8. builds the Workshop upload folder (prepare-workshop.sh)
#   Then: game > Workshop > Create and update items > PZBackup > Update.
set -u

ok()    { printf '  \033[32m✔ %s\033[0m\n' "$1"; }
info()  { printf '  %s\n' "$1"; }
warn()  { printf '  \033[33m! %s\033[0m\n' "$1"; }
fail()  { printf '\n\033[31mERROR: %s\033[0m\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2"; exit 1; }
etapa() { printf '\n\033[1m%s\033[0m\n' "$1"; }

REPO="$HOME/Projetos/PZBackup"
PATCH=""; ZIP=""; WS_VIS="--public"; RELEASE=1; YES=0
GH_REPO="${PZB_GH_REPO:-ahlrodrigues/PZBackup}"
MIRROR_WAIT="${PZB_MIRROR_WAIT:-600}"     # seconds to wait for the tag to reach GitHub

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)  REPO="$2"; shift ;;
    --patch) PATCH="$2"; shift ;;
    --zip)   ZIP="$2"; shift ;;
    --private) WS_VIS="" ;;
    --no-release) RELEASE=0 ;;
    --yes|-y) YES=1 ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) fail "Unknown option: $1 (see --help)" ;;
  esac
  shift
done

confirmar() {   # confirmar "question" -> 0 if yes
  [ "$YES" = 1 ] && return 0
  local r; read -rp "  $1 (y/N) " r
  case "$r" in y|Y|s|S) return 0 ;; *) return 1 ;; esac
}

echo
echo "=== PZ Backup: publish ==="

# ---------------------------------------------------------------- 1. Files
etapa "1. Downloaded files"
if [ -z "$PATCH" ]; then
  PATCH=$(ls -t "$HOME"/Downloads/PZBackup-v*.patch 2>/dev/null | head -n1)
  [ -n "$PATCH" ] || fail "No PZBackup-v*.patch in ~/Downloads." "Pass it with: --patch /path/to/file.patch"
fi
[ -f "$PATCH" ] || fail "Patch not found: $PATCH"
ok "Patch: $PATCH ($(date -r "$PATCH" '+%d/%m %H:%M'))"
ASSUNTO=$(sed -n 's/^Subject: \(\[PATCH[^]]*\] \)\{0,1\}//p' "$PATCH" | head -n1)
info "Commit: $ASSUNTO"

# ---------------------------------------------------------------- 2. Repository
etapa "2. Repository"
[ -d "$REPO/.git" ] || fail "$REPO is not a git repository." "Use --repo /path/to/PZBackup"
cd "$REPO" || fail "Can't enter $REPO"
command -v git >/dev/null || fail "git not found."

if [ -d .git/rebase-apply ]; then
  fail "A previous 'git am' was left unfinished in $REPO." "Run: cd $REPO && git am --abort   (then run this again)"
fi
[ -z "$(git status --porcelain)" ] || fail "There are uncommitted changes in $REPO:" "$(git status --short)
Commit or discard them (git stash) and run this again."

RAMO=$(git symbolic-ref --short HEAD 2>/dev/null) || fail "Detached HEAD in $REPO: check out your branch (git checkout main)."
REMOTO=$(git config "branch.$RAMO.remote" || echo origin)
ok "Branch $RAMO, remote $REMOTO ($(git remote get-url "$REMOTO" 2>/dev/null || echo '?'))"

if git fetch -q "$REMOTO" 2>/dev/null; then
  if git rev-parse -q --verify "$REMOTO/$RAMO" >/dev/null; then
    if ! git merge-base --is-ancestor "$REMOTO/$RAMO" HEAD; then
      if git merge-base --is-ancestor HEAD "$REMOTO/$RAMO"; then
        git merge -q --ff-only "$REMOTO/$RAMO" && ok "Updated from $REMOTO ($(git log -1 --format=%h))"
      else
        fail "Your $RAMO and $REMOTO/$RAMO have diverged." "Sort it out by hand (git log --oneline --graph --all) and run this again."
      fi
    else
      ok "Up to date with $REMOTO"
    fi
  fi
else
  warn "Couldn't reach $REMOTO (offline?). Continuing with the local copy."
fi

# Already on the remote? (then the commit can't be rewritten)
publicado() { git rev-parse -q --verify "$REMOTO/$RAMO" >/dev/null && git merge-base --is-ancestor "$1" "$REMOTO/$RAMO"; }

# ---------------------------------------------------------------- 3. Patch
etapa "3. Applying the patch"
aplicar() {
  git am -q --3way "$PATCH" && return 0
  git am --abort 2>/dev/null
  return 1
}
VER_PATCH=$(printf '%s' "$ASSUNTO" | sed -n 's/^PZ Backup \([0-9][0-9.]*\).*/\1/p')
mesma_versao() { git log -1 --format=%s "$1" | grep -q "^PZ Backup ${VER_PATCH:-x.x.x}\b"; }
id_patch() { git patch-id --stable | cut -d' ' -f1; }

# Tree that HEAD~1 would have with the patch applied (empty if it doesn't apply there)
arvore_sobre_anterior() {
  local idx; idx=$(mktemp)
  if GIT_INDEX_FILE="$idx" git read-tree HEAD~1 2>/dev/null &&
     GIT_INDEX_FILE="$idx" git apply --cached "$PATCH" 2>/dev/null; then
    GIT_INDEX_FILE="$idx" git write-tree
  fi
  rm -f "$idx"
}

if git apply --check "$PATCH" 2>/dev/null; then
  aplicar || fail "git am failed." "Nothing was changed. Check that the patch matches your repository."
  ok "Applied: $(git log -1 --format='%h %s')"
elif [ "$(id_patch < "$PATCH")" = "$(git show HEAD | id_patch)" ]; then
  ok "Already applied (nothing to do): $(git log -1 --format='%h %s')"
elif mesma_versao HEAD && NOVA_ARVORE=$(arvore_sobre_anterior) && [ -n "$NOVA_ARVORE" ]; then
  # An updated delivery of the same version: your last commit is an older copy of it
  if [ "$NOVA_ARVORE" = "$(git rev-parse 'HEAD^{tree}')" ]; then
    ok "Already up to date (same files): $(git log -1 --format='%h %s')"
  elif ! publicado HEAD; then
    warn "The patch is an updated version of your last commit (not pushed yet):"
    info "  now:  $(git log -1 --format='%h %s')"
    info "  new:  $ASSUNTO"
    confirmar "Replace the last commit with the new patch?" || fail "Cancelled. Nothing was changed."
    VELHO=$(git rev-parse HEAD)
    git reset -q --hard HEAD~1
    if aplicar; then
      ok "Replaced: $(git log -1 --format='%h %s') (old commit: ${VELHO:0:7})"
    else
      git reset -q --hard "$VELHO"
      fail "The new patch didn't apply; your old commit was put back."
    fi
  else
    # Already pushed: never rewrite history; add a commit that brings the files
    # to what the new patch delivers
    warn "The patch is an updated version of $(git log -1 --format='%h') (already pushed):"
    git diff --stat HEAD "$NOVA_ARVORE" | tail -n1 | sed 's/^/    /'
    confirmar "Add a commit on top with the updated files?" || fail "Cancelled. Nothing was changed."
    NOVO=$(git commit-tree "$NOVA_ARVORE" -p HEAD -m "PZ Backup $VER_PATCH: updated delivery

Brings the files to the latest $VER_PATCH patch ($ASSUNTO).")
    git reset -q --hard "$NOVO"
    ok "Update commit: $(git log -1 --format='%h %s')"
  fi
elif git apply --check --reverse "$PATCH" 2>/dev/null; then
  ok "Already applied (its changes are in the repository): $(git log -1 --format='%h %s')"
else
  fail "The patch doesn't apply to $REPO." "Your repository may be ahead of or behind what the patch expects.
Last commit here: $(git log -1 --format='%h %s')"
fi

# ---------------------------------------------------------------- 4. Version
etapa "4. Version"
[ -x tools/bump-version.sh ] || chmod +x tools/bump-version.sh 2>/dev/null
bash tools/bump-version.sh --check || fail "Versions differ between files: nothing was pushed."
VER=$(sed -n 's/^modversion=//p' files/mod/PZBackup/42/mod.info | tr -d '\r')
TAG="v$VER"
ok "Version $VER"
# CHANGELOG notes of this version (for the GitHub release)
NOTAS=$(awk -v v="$VER" '$0 ~ "^## \\[" v "\\]" {f = 1; next} f && /^## \[/ {exit} f' CHANGELOG.md)
[ -n "$NOTAS" ] || warn "No CHANGELOG section for $VER"

# ---------------------------------------------------------------- 5. Push
etapa "5. Push to $REMOTO"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  if [ "$(git rev-list -n1 "$TAG")" != "$(git rev-parse HEAD)" ]; then
    if git ls-remote --exit-code --tags "$REMOTO" "refs/tags/$TAG" >/dev/null 2>&1; then
      fail "Tag $TAG already exists on $REMOTO pointing to another commit." "If that release is wrong, delete the tag there first (git push $REMOTO :refs/tags/$TAG) and run this again."
    fi
    git tag -f "$TAG" >/dev/null && ok "Local tag $TAG moved to $(git log -1 --format=%h)"
  fi
else
  git tag -a "$TAG" -m "PZ Backup $VER" && ok "Tag $TAG created"
fi

PENDENTES=$(git rev-list --count "$REMOTO/$RAMO..HEAD" 2>/dev/null || echo "?")
info "Commits to push: $PENDENTES; tag: $TAG"
if confirmar "Push $RAMO and $TAG to $REMOTO?"; then
  git push -q "$REMOTO" "$RAMO" || fail "git push failed." "Fix the problem and run this again (it picks up where it stopped)."
  git push -q "$REMOTO" "refs/tags/$TAG" 2>/dev/null || git push -q --force "$REMOTO" "refs/tags/$TAG" ||
    fail "Pushing tag $TAG failed."
  ok "Pushed $RAMO and $TAG"
else
  warn "Push skipped. Run this again when you're ready (it's safe to repeat)."
  RELEASE=0
fi

# ---------------------------------------------------------------- 6. GitHub release
etapa "6. GitHub release $TAG"
if [ "$RELEASE" = 1 ]; then
  [ -n "$ZIP" ] || ZIP="$HOME/Downloads/PZBackup-$TAG.zip"
  if ! command -v gh >/dev/null; then
    warn "gh (GitHub CLI) not installed: create the release by hand on GitHub and attach $(basename "$ZIP")"
  elif ! gh auth status >/dev/null 2>&1; then
    warn "gh isn't logged in (gh auth login): create the release by hand and attach $(basename "$ZIP")"
  elif [ ! -f "$ZIP" ]; then
    warn "Release zip not found: $ZIP — skipping the release (use --zip FILE)"
  else
    ZVER=$(unzip -p "$ZIP" '*/files/mod/PZBackup/42/mod.info' 2>/dev/null | sed -n 's/^modversion=//p' | tr -d '\r')
    if [ "$ZVER" != "$VER" ]; then
      warn "$(basename "$ZIP") contains version ${ZVER:-?}, not $VER — skipping the release"
    else
      # The tag reaches GitHub through the Forgejo mirror: wait for it
      info "Waiting for $TAG to reach GitHub through the mirror (up to $((MIRROR_WAIT / 60)) min)..."
      esperou=0
      until [ "$(gh api "repos/$GH_REPO/commits/$TAG" -q .sha 2>/dev/null)" = "$(git rev-parse HEAD)" ]; do
        if [ "$esperou" -ge "$MIRROR_WAIT" ]; then esperou=-1; break; fi
        sleep 15; esperou=$((esperou + 15)); printf '.'
      done
      [ "$esperou" -gt 0 ] && echo
      if [ "$esperou" = -1 ]; then
        warn "$TAG didn't show up on GitHub yet. Sync the mirror in Forgejo (Settings > Repository > Mirror > Synchronize now) and run this again."
      else
        NOTAS_ARQ=$(mktemp); printf '%s\n' "$NOTAS" > "$NOTAS_ARQ"
        if gh release view "$TAG" -R "$GH_REPO" >/dev/null 2>&1; then
          gh release upload "$TAG" "$ZIP" --clobber -R "$GH_REPO" >/dev/null &&
            gh release edit "$TAG" --notes-file "$NOTAS_ARQ" -R "$GH_REPO" >/dev/null &&
            ok "Release $TAG updated (zip replaced)"
        else
          gh release create "$TAG" "$ZIP" --title "PZ Backup $VER" --notes-file "$NOTAS_ARQ" --verify-tag -R "$GH_REPO" >/dev/null &&
            ok "Release $TAG created with $(basename "$ZIP")"
        fi || warn "gh couldn't create/update the release: do it by hand on GitHub"
        rm -f "$NOTAS_ARQ"
      fi
    fi
  fi
else
  info "Skipped."
fi

# ---------------------------------------------------------------- 7. Local script
etapa "7. Backup script on this PC"
BASE=""
for b in "$HOME/Zomboid" "$HOME/.var/app/com.valvesoftware.Steam/Zomboid"; do
  [ -d "$b" ] && { BASE="$b"; break; }
done
if [ -z "$BASE" ]; then
  warn "Zomboid folder not found: script not installed"
else
  DESTINO_SH="$BASE/pz-backup.sh"
  ANTES=$(sed -n 's/^VERSION="\(.*\)".*/\1/p' "$DESTINO_SH" 2>/dev/null)
  if pgrep -f "pz-backup.sh (game|jogo)" >/dev/null 2>&1; then
    warn "The game (with the backup script) is running: the new script takes effect next time you start it"
  fi
  # Write a new file and rename it: a running copy keeps reading the old one safely
  cp "files/linux/pz-backup.sh" "$DESTINO_SH.novo" && chmod 755 "$DESTINO_SH.novo" &&
    mv -f "$DESTINO_SH.novo" "$DESTINO_SH" &&
    ok "pz-backup.sh ${ANTES:-?} -> $VER in $BASE"
  if [ -d "$BASE/mods/PZBackup" ]; then
    warn "There's a local copy of the mod in $BASE/mods/PZBackup (same Mod ID as the Workshop one)."
    info "  If you play with the Workshop version, remove it: rm -rf \"$BASE/mods/PZBackup\""
  fi
  command -v rsync >/dev/null || warn "rsync not found: backups will be full copies (install rsync for incremental backups)"
fi

# ---------------------------------------------------------------- 8. Workshop folder
etapa "8. Workshop upload folder"
# shellcheck disable=SC2086
bash workshop/prepare-workshop.sh $WS_VIS || fail "prepare-workshop.sh failed."

cat <<EOF

$(printf '\033[1;32m')=== All set: PZ Backup $VER ===$(printf '\033[0m')
  Now, in the game:
    Workshop > Create and update items > PZBackup > Update
  Then subscribers get $VER automatically.
EOF
