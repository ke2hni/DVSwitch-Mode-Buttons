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

patch_dmr_helper(){
  HELPER="$tmp/dvswitch-dmr-network.sh.$BACKEND_BASE" python3 - <<'PY'
from pathlib import Path
import os

path = Path(os.environ['HELPER'])
text = path.read_text(encoding='utf-8')

if 'Analog_Bridge.ini' in text or 'analog_preset' in text:
    raise SystemExit('ERROR: source DMR helper must not contain Analog_Bridge handling')
if 'systemctl restart analog_bridge mmdvm_bridge' not in text:
    raise SystemExit('ERROR: expected DMR service restart was not found')

state_function = r'''
update_state(){
    local state_file=/var/lib/mmdvm/dvswitch-mods-dmr-state.json
    [[ -e "$state_file" ]] || return 0
    STATE_FILE="$state_file" NETWORK="$1" python3 - <<'PY_STATE'
import json
import os
import stat
import tempfile
from pathlib import Path

path = Path(os.environ['STATE_FILE'])
network = os.environ['NETWORK'].upper()
with path.open(encoding='utf-8') as source:
    state = json.load(source)
if not isinstance(state, dict):
    raise ValueError('DMR state is not a JSON object')
state['current_network'] = network
mode = stat.S_IMODE(path.stat().st_mode)
fd, name = tempfile.mkstemp(prefix=f'.{path.name}.', dir=str(path.parent), text=True)
try:
    with os.fdopen(fd, 'w', encoding='utf-8') as target:
        json.dump(state, target, indent=4)
        target.write('\n')
    os.chown(name, path.stat().st_uid, path.stat().st_gid)
    os.chmod(name, mode)
    os.replace(name, path)
except Exception:
    try:
        os.unlink(name)
    except FileNotFoundError:
        pass
    raise
PY_STATE
}
'''
text = text.replace('\nsystemctl restart analog_bridge mmdvm_bridge', state_function + '\nsystemctl restart analog_bridge mmdvm_bridge', 1)
text = text.replace('systemctl is-active --quiet analog_bridge mmdvm_bridge || die "DVSwitch service verification failed"\n', 'systemctl is-active --quiet analog_bridge mmdvm_bridge || die "DVSwitch service verification failed"\nupdate_state "$network" || die "could not update DMR network state"\n', 1)

if 'Analog_Bridge.ini' in text or 'analog_preset' in text or 'update_state "$network"' not in text:
    raise SystemExit('ERROR: generated DMR helper failed final validation')
path.write_text(text, encoding='utf-8', newline='\n')
PY
}

show "$BACKEND_BASE" dvswitch-mode-buttons.sh
show "$BACKEND_BASE" dvswitch-dmr-network.sh
show "$HELPER_BASE" dvswitch-mode-buttons
show "$ENDPOINT_BASE" dvswitch-mode-buttons.php
show "$BACKEND_BASE" dvswitch-mode-buttons.sudoers

patch_dmr_helper

install -o root -g root -m 755 "$tmp/dvswitch-mode-buttons.$HELPER_BASE" /usr/local/sbin/dvswitch-mode-buttons
install -o root -g root -m 755 "$tmp/dvswitch-dmr-network.sh.$BACKEND_BASE" /usr/local/sbin/dvswitch-dmr-network
install -o root -g root -m 644 "$tmp/dvswitch-mode-buttons.php.$ENDPOINT_BASE" /usr/share/dvswitch/dvswitch-mode-buttons.php
install -o root -g root -m 440 "$tmp/dvswitch-mode-buttons.sudoers.$BACKEND_BASE" /etc/sudoers.d/dvswitch-mode-buttons

visudo -cf /etc/sudoers.d/dvswitch-mode-buttons >/dev/null || die 'sudoers validation failed'
php -l /usr/share/dvswitch/dvswitch-mode-buttons.php >/dev/null || die 'endpoint PHP validation failed'
bash -n /usr/local/sbin/dvswitch-mode-buttons /usr/local/sbin/dvswitch-dmr-network
grep -qF 'update_state "$network"' /usr/local/sbin/dvswitch-dmr-network || die 'DMR state update is missing'
if grep -qF 'Analog_Bridge.ini' /usr/local/sbin/dvswitch-dmr-network; then
  die 'DMR helper must not modify Analog_Bridge.ini'
fi

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
echo 'PASS: DMR helper updates the Mods network state and does not modify Analog_Bridge.ini.'
