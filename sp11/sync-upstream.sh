#!/bin/bash
# Bring the sp11 branch up to date with upstream omacom/omarchy:
#   dragon  - the aarch64 line this fork started from
#   quattro - Omarchy's main line, which dragon lags behind
# Merges both into sp11 (git rerere replays conflict resolutions made before),
# runs the platform tests, and pushes with --push.
#
# Usage: sp11/sync-upstream.sh [--push]
# On a conflict it stops on the merge: resolve, `git commit`, then run it again.
set -euo pipefail

branch=sp11
tests=(hw-platform pacman-templates image-target-platform mkinitcpio-hooks mkinitcpio-apple-drop-ins platform-app-hooks)

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

cd "$(git rev-parse --show-toplevel)"
[[ $(git rev-parse --abbrev-ref HEAD) == "$branch" ]] || die "switch to $branch first (git switch $branch)"
git diff --quiet && git diff --cached --quiet || die "working tree has uncommitted changes"
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/omacom/omarchy.git
git config rerere.enabled true
git config rerere.autoupdate true

say "Fetching upstream dragon + quattro"
git fetch --quiet upstream dragon quattro
before=$(git rev-parse HEAD)

for up in dragon quattro; do
  if git merge-base --is-ancestor "upstream/$up" HEAD; then
    echo "  $up: nothing new"
    continue
  fi
  say "Merging upstream/$up ($(git rev-list --count "HEAD..upstream/$up") new commits)"
  git rev-list --oneline "HEAD..upstream/$up" -- bin/omarchy-hw-platform install/helpers/pacman.sh \
    install/post-install/pacman.sh default/pacman etc/mkinitcpio.conf.d bin/omarchy-pkg-defaults |
    sed 's/^/  touches platform code: /'
  if ! git merge --no-edit -m "Merge upstream $up into $branch" "upstream/$up"; then
    conflicts=$(git diff --name-only --diff-filter=U)
    if [[ -n $conflicts ]]; then
      echo "$conflicts" | sed 's/^/  conflict: /'
      die "resolve the conflicts above (keep the aarch64-surface pieces), git commit, then run this again
       (undo the whole sync instead: git merge --abort; git reset --hard $before)"
    fi
    git commit --no-edit   # rerere resolved every conflict
  fi
done

if [[ $(git rev-parse HEAD) == "$before" ]]; then
  say "Already up to date"
  exit 0
fi

say "Platform tests"
failed=()
for t in "${tests[@]}"; do
  if bash "test/shell.d/$t-test.sh" >/dev/null 2>&1; then echo "  PASS $t"; else echo "  FAIL $t"; failed+=("$t"); fi
done
if [[ $(bash -p bin/omarchy-hw-platform 2>/dev/null) != aarch64-surface && -e /proc/device-tree/compatible ]] &&
  tr '\0' '\n' </proc/device-tree/compatible | grep -qx 'microsoft,denali'; then
  failed+=("live platform is not aarch64-surface")
fi
((${#failed[@]} == 0)) || die "failed: ${failed[*]} - inspect, or undo with: git reset --hard $before"

say "Merged $(git rev-list --count "$before..HEAD") commits"
if [[ ${1:-} == --push ]]; then
  git push origin "$branch"
else
  echo "  not pushed - run with --push, or: git push origin $branch"
fi
if [[ $(cat /etc/omarchy.conf 2>/dev/null) == *"$PWD"* ]]; then
  echo "  this checkout is dev-linked: run 'omarchy restart shell' (or reboot for everything)"
fi
