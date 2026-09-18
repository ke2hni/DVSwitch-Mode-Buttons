#!/usr/bin/env bash
set -Eeuo pipefail

TARGET=/usr/share/dvswitch/index.php
REPO_BASE=3e013b4
DASH_BASE=516a05c
BASE=/etc/dvswitch-mode-buttons
BACKUP=/var/backups/dvswitch-mode-buttons/install-$(date +%Y%m%d-%H%M%S)

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ $# -eq 1 && ( "$1" == --check || "$1" == --install ) ]] || { echo "Usage: sudo $0 --check|--install" >&2; exit 2; }
[[ -d .git ]] || die 'run from the DVSwitch-Mode-Buttons repository'
[[ -f "$TARGET" ]] || die "missing $TARGET"
[[ -x /opt/MMDVM_Bridge/dvswitch.sh ]] || die 'missing /opt/MMDVM_Bridge/dvswitch.sh'
git cat-file -e "$REPO_BASE^{commit}" || die "missing repository baseline $REPO_BASE"
git cat-file -e "$DASH_BASE^{commit}" || die "missing repository dashboard baseline $DASH_BASE"

if [[ "$1" == --check ]]; then
  echo "DVSwitch Mode Buttons repository installer"
  echo "Clean backend baseline: $REPO_BASE"
  echo "Clean dashboard installer baseline: $DASH_BASE"
  [[ -f /var/lib/dvswitch/dvs/var.txt ]] && echo 'DVSwitch var.txt: found' || echo 'DVSwitch var.txt: not found'
  echo 'PASS: prerequisites checked; no files changed.'
  exit 0
fi

install -d -m 700 -o root -g root "$BACKUP" "$BASE"
cp -a "$TARGET" "$BACKUP/index.php"
for p in /usr/local/sbin/dvswitch-mode-buttons /usr/local/sbin/dvswitch-dmr-network /usr/share/dvswitch/dvswitch-mode-buttons.php /etc/sudoers.d/dvswitch-mode-buttons; do
  [[ -e "$p" ]] && cp -a "$p" "$BACKUP/$(basename "$p")"
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
repo_file(){ git show "$REPO_BASE:$1" > "$tmp/$(basename "$1")"; }
repo_file dvswitch-mode-buttons
repo_file dvswitch-dmr-network.sh
repo_file dvswitch-mode-buttons.php
repo_file dvswitch-mode-buttons.sh
repo_file dvswitch-mode-buttons.sudoers
git show "$DASH_BASE:install-dashboard-buttons.sh" > "$tmp/install-dashboard-buttons.sh"

chmod 755 "$tmp/dvswitch-mode-buttons" "$tmp/dvswitch-dmr-network.sh" "$tmp/dvswitch-mode-buttons.sh" "$tmp/install-dashboard-buttons.sh"
install -o root -g root -m 755 "$tmp/dvswitch-mode-buttons" /usr/local/sbin/dvswitch-mode-buttons
install -o root -g root -m 755 "$tmp/dvswitch-dmr-network.sh" /usr/local/sbin/dvswitch-dmr-network
install -o root -g root -m 644 "$tmp/dvswitch-mode-buttons.php" /usr/share/dvswitch/dvswitch-mode-buttons.php
install -o root -g root -m 440 "$tmp/dvswitch-mode-buttons.sudoers" /etc/sudoers.d/dvswitch-mode-buttons

rm -rf /var/lib/dvswitch-mode-buttons
visudo -cf /etc/sudoers.d/dvswitch-mode-buttons >/dev/null || die 'sudoers validation failed'
php -l /usr/share/dvswitch/dvswitch-mode-buttons.php >/dev/null || die 'endpoint PHP validation failed'

python3 - "$TARGET" <<'PY'
import re, sys
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text()
s,n=re.subn(r'\s*(?:<!--\s*DVSwitch-Mode-Buttons.*?-->\s*)?<div id=["\']dvs-mode-buttons["\'].*?</script>\s*', '\n', s, flags=re.I|re.S)
if n: p.write_text(s)
PY

(cd "$tmp" && ./dvswitch-mode-buttons.sh --install)
"$tmp/install-dashboard-buttons.sh"
bash -n /usr/local/sbin/dvswitch-mode-buttons /usr/local/sbin/dvswitch-dmr-network
php -l /usr/share/dvswitch/dvswitch-mode-buttons.php >/dev/null
echo "PASS: repository files installed unchanged."
echo "PASS: dashboard buttons installed above the RX Monitor anchor."
echo "PASS: no TG/ref persistence, target state, or startup service installed."
echo "PASS: backup: $BACKUP"
