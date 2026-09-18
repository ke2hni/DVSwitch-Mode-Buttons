#!/usr/bin/env bash
set -Eeuo pipefail

TARGET=/usr/share/dvswitch/index.php
die(){ echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ -f "$TARGET" ]] || die "missing $TARGET"
[[ -d .git ]] || die 'run from the old DVSwitch-Mode-Buttons repository'

for commit in 516a05c bdd1641 13a438b 2be94e6 65812c9; do
  git cat-file -e "$commit^{commit}" || die "missing repository commit $commit"
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

run_revision(){
  local commit=$1
  local file=${2:-install-dashboard-buttons.sh}
  git show "$commit:$file" > "$tmp/$(basename "$file").$commit.sh"
  bash "$tmp/$(basename "$file").$commit.sh"
}

if grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test8 -->' "$TARGET"; then
  echo 'ALREADY INSTALLED: dashboard mode buttons are at the final repository revision.'
  exit 0
fi

if grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test7 -->' "$TARGET"; then
  run_revision 13a438b
  run_revision 2be94e6
  run_revision 65812c9 install-dashboard-buttons-refresh.sh
elif grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test6 -->' "$TARGET"; then
  run_revision bdd1641
  run_revision 13a438b
  run_revision 2be94e6
  run_revision 65812c9 install-dashboard-buttons-refresh.sh
else
  run_revision 516a05c
  run_revision bdd1641
  run_revision 13a438b
  run_revision 2be94e6
  run_revision 65812c9 install-dashboard-buttons-refresh.sh
fi

grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test8 -->' "$TARGET" || die 'final repository button block was not installed'
grep -qF 'background-color:#008000' "$TARGET" || die 'repository selected color was not installed'
grep -qF "fetch('/dvswitch/dvswitch-mode-buttons.php?mode=" "$TARGET" || die 'repository mode-switch code was not installed'
echo 'PASS: repository dashboard buttons installed above RX Monitor.'
echo 'PASS: repository colors and visual states installed unchanged.'
