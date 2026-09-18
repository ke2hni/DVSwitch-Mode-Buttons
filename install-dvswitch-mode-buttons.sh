#!/usr/bin/env bash
set -Eeuo pipefail

TARGET=/usr/share/dvswitch/index.php
BACKEND_BASE=3e013b4
HELPER_BASE=32d64a2
ENDPOINT_BASE=25e144a
DASHBOARD_BASE=65812c9
SEED_BASE=516a05c
HORIZONTAL_BASE=bdd1641
GREEN_BASE=2be94e6

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ -d .git ]] || die 'run from the DVSwitch-Mode-Buttons repository'
[[ -f "$TARGET" ]] || die "missing $TARGET"

for spec in \
  "$BACKEND_BASE:dvswitch-mode-buttons" \
  "$BACKEND_BASE:dvswitch-mode-buttons.sh" \
  "$BACKEND_BASE:dvswitch-dmr-network.sh" \
  "$BACKEND_BASE:dvswitch-mode-buttons.sudoers" \
  "$HELPER_BASE:dvswitch-mode-buttons" \
  "$ENDPOINT_BASE:dvswitch-mode-buttons.php" \
  "$SEED_BASE:install-dashboard-buttons.sh" \
  "$HORIZONTAL_BASE:install-dashboard-buttons.sh" \
  "$GREEN_BASE:install-dashboard-buttons.sh" \
  "$DASHBOARD_BASE:install-dashboard-buttons-refresh.sh"; do
  git cat-file -e "$spec" || die "missing repository source $spec"
done

[[ ${1:-} == --check ]] || [[ ${1:-} == --install ]] || {
  echo "Usage: sudo $0 --check|--install" >&2
  exit 2
}

if [[ $1 == --check ]]; then
  [[ -f /var/lib/dvswitch/dvs/var.txt ]] || die 'missing /var/lib/dvswitch/dvs/var.txt'
  [[ -x /opt/MMDVM_Bridge/dvswitch.sh ]] || die 'missing /opt/MMDVM_Bridge/dvswitch.sh'
  [[ -f /opt/MMDVM_Bridge/MMDVM_Bridge.ini ]] || die 'missing /opt/MMDVM_Bridge/MMDVM_Bridge.ini'
  echo 'PASS: unified repository sources and node prerequisites verified; no files changed.'
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
show(){ git show "$1:$2" > "$tmp/$(basename "$2").$1"; }

show "$BACKEND_BASE" dvswitch-mode-buttons.sh
show "$BACKEND_BASE" dvswitch-dmr-network.sh
show "$HELPER_BASE" dvswitch-mode-buttons
show "$ENDPOINT_BASE" dvswitch-mode-buttons.php
show "$BACKEND_BASE" dvswitch-mode-buttons.sudoers

install -o root -g root -m 755 "$tmp/dvswitch-mode-buttons.$HELPER_BASE" /usr/local/sbin/dvswitch-mode-buttons
install -o root -g root -m 755 "$tmp/dvswitch-dmr-network.sh.$BACKEND_BASE" /usr/local/sbin/dvswitch-dmr-network
install -o root -g root -m 644 "$tmp/dvswitch-mode-buttons.php.$ENDPOINT_BASE" /usr/share/dvswitch/dvswitch-mode-buttons.php
install -o root -g root -m 440 "$tmp/dvswitch-mode-buttons.sudoers.$BACKEND_BASE" /etc/sudoers.d/dvswitch-mode-buttons

visudo -cf /etc/sudoers.d/dvswitch-mode-buttons >/dev/null || die 'sudoers validation failed'
php -l /usr/share/dvswitch/dvswitch-mode-buttons.php >/dev/null || die 'endpoint PHP validation failed'
bash -n /usr/local/sbin/dvswitch-mode-buttons /usr/local/sbin/dvswitch-dmr-network

bash "$tmp/dvswitch-mode-buttons.sh.$BACKEND_BASE" --install

if ! grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test8 -->' "$TARGET"; then
  show "$SEED_BASE" install-dashboard-buttons.sh
  show "$HORIZONTAL_BASE" install-dashboard-buttons.sh
  show "$GREEN_BASE" install-dashboard-buttons.sh
  show "$DASHBOARD_BASE" install-dashboard-buttons-refresh.sh
  bash "$tmp/install-dashboard-buttons.sh.$SEED_BASE"
  bash "$tmp/install-dashboard-buttons.sh.$HORIZONTAL_BASE"
  bash "$tmp/install-dashboard-buttons.sh.$GREEN_BASE"
  bash "$tmp/install-dashboard-buttons-refresh.sh.$DASHBOARD_BASE"
fi

grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test8 -->' "$TARGET" || die 'final dashboard block missing'
grep -qF 'background-color:#008000' "$TARGET" || die 'selected color missing'
grep -qF "fetch('/dvswitch/dvswitch-mode-buttons.php?status=1" "$TARGET" || die 'refresh code missing'
grep -qF "fetch('/dvswitch/dvswitch-mode-buttons.php?mode=" "$TARGET" || die 'mode-switch request missing'

echo 'PASS: unified dashboard, refresh, endpoint, helper, sudoers, and BM/TGIF installer installed.'
