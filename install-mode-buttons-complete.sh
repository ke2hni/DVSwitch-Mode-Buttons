#!/usr/bin/env bash
set -Eeuo pipefail

TARGET=/usr/share/dvswitch/index.php
BACKEND_BASE=3e013b4
die(){ echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ -d .git ]] || die 'run from the DVSwitch-Mode-Buttons repository'
[[ -f "$TARGET" ]] || die "missing $TARGET"
for f in dvswitch-mode-buttons dvswitch-dmr-network.sh dvswitch-mode-buttons.php dvswitch-mode-buttons.sh dvswitch-mode-buttons.sudoers; do
  git cat-file -e "$BACKEND_BASE:$f" || die "missing repository file $f at $BACKEND_BASE"
done

if [[ ${1:-} == --check ]]; then
  echo 'DVSwitch mode-button complete installer'
  echo "Backend repository baseline: $BACKEND_BASE"
  [[ -f /var/lib/dvswitch/dvs/var.txt ]] && echo 'DVSwitch var.txt: found' || die 'missing /var/lib/dvswitch/dvs/var.txt'
  [[ -f /opt/MMDVM_Bridge/MMDVM_Bridge.ini ]] || die 'missing /opt/MMDVM_Bridge/MMDVM_Bridge.ini'
  [[ -f /opt/MMDVM_Bridge/dvswitch.sh ]] || die 'missing /opt/MMDVM_Bridge/dvswitch.sh'
  echo 'PASS: prerequisites checked; no files changed.'
  exit 0
fi
[[ ${1:-} == --install ]] || { echo "Usage: sudo $0 --check|--install" >&2; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
extract(){ git show "$BACKEND_BASE:$1" > "$tmp/$(basename "$1")"; }
extract dvswitch-mode-buttons
extract dvswitch-dmr-network.sh
extract dvswitch-mode-buttons.php
extract dvswitch-mode-buttons.sh
extract dvswitch-mode-buttons.sudoers

install -o root -g root -m 755 "$tmp/dvswitch-mode-buttons" /usr/local/sbin/dvswitch-mode-buttons
install -o root -g root -m 755 "$tmp/dvswitch-dmr-network.sh" /usr/local/sbin/dvswitch-dmr-network
install -o root -g root -m 644 "$tmp/dvswitch-mode-buttons.php" /usr/share/dvswitch/dvswitch-mode-buttons.php
install -o root -g root -m 440 "$tmp/dvswitch-mode-buttons.sudoers" /etc/sudoers.d/dvswitch-mode-buttons
visudo -cf /etc/sudoers.d/dvswitch-mode-buttons >/dev/null || die 'sudoers validation failed'
php -l /usr/share/dvswitch/dvswitch-mode-buttons.php >/dev/null || die 'endpoint PHP validation failed'

bash "$tmp/dvswitch-mode-buttons.sh" --install

grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test8 -->' "$TARGET" || die 'dashboard test8 button block is missing'
grep -qF 'background-color:#008000' "$TARGET" || die 'selected button color is missing'
grep -qF "fetch('/dvswitch/dvswitch-mode-buttons.php?mode=" "$TARGET" || die 'dashboard mode-switch request is missing'

bash -n /usr/local/sbin/dvswitch-mode-buttons /usr/local/sbin/dvswitch-dmr-network
echo 'PASS: exact repository mode-switch helpers installed.'
echo 'PASS: exact repository endpoint and sudoers rules installed.'
echo 'PASS: dashboard buttons and selected color verified.'
