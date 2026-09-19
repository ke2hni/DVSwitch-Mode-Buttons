#!/usr/bin/env bash
# DVSwitch Mode Buttons all-in-one installer v4
set -Eeuo pipefail

TARGET=/usr/share/dvswitch/index.php
MODE_HELPER=/usr/local/sbin/dvswitch-mode-buttons
DMR_HELPER=/usr/local/sbin/dvswitch-dmr-network
ENDPOINT=/usr/share/dvswitch/dvswitch-mode-buttons.php
SUDOERS=/etc/sudoers.d/dvswitch-mode-buttons
PRESET_DIR=/etc/dvswitch-mode-buttons
BACKEND_BASE=3e013b4
HELPER_BASE=32d64a2
ENDPOINT_BASE=25e144a
DASHBOARD_BASE=65812c9
SEED_BASE=516a05c
HORIZONTAL_BASE=bdd1641
GREEN_BASE=2be94e6
UPGRADE_BASE=13a438b

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
  "$UPGRADE_BASE:install-dashboard-buttons.sh" \
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
  echo 'PASS: unified repository sources and node prerequisites verified.'
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

dashboard_complete(){
  grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test8 -->' "$TARGET" || return 1
  grep -qF 'background-color:#008000' "$TARGET" || return 1
  grep -qF "fetch('/dvswitch/dvswitch-mode-buttons.php?status=1" "$TARGET" || return 1
  grep -qF "fetch('/dvswitch/dvswitch-mode-buttons.php?mode=" "$TARGET" || return 1
}

backend_complete(){
  [[ -f "$MODE_HELPER" ]] && cmp -s "$tmp/dvswitch-mode-buttons.$HELPER_BASE" "$MODE_HELPER" || return 1
  [[ -f "$DMR_HELPER" ]] && cmp -s "$tmp/dvswitch-dmr-network.sh.$BACKEND_BASE" "$DMR_HELPER" || return 1
  [[ -f "$ENDPOINT" ]] && cmp -s "$tmp/dvswitch-mode-buttons.php.$ENDPOINT_BASE" "$ENDPOINT" || return 1
  [[ -f "$SUDOERS" ]] && cmp -s "$tmp/dvswitch-mode-buttons.sudoers.$BACKEND_BASE" "$SUDOERS" || return 1
  [[ -f "$PRESET_DIR/MMDVM_Bridge.BM.ini" && -f "$PRESET_DIR/MMDVM_Bridge.TGIF.ini" ]] || return 1
}

installation_complete(){
  backend_complete && dashboard_complete
}

if [[ $1 == --check ]]; then
  if installation_complete; then
    echo 'ALREADY INSTALLED: unified DVSwitch mode buttons are complete; no files changed.'
  else
    partial=0
    for path in "$MODE_HELPER" "$DMR_HELPER" "$ENDPOINT" "$SUDOERS" "$PRESET_DIR/MMDVM_Bridge.BM.ini" "$PRESET_DIR/MMDVM_Bridge.TGIF.ini"; do
      [[ -e "$path" ]] && partial=1
    done
    grep -qF 'DVSwitch-Mode-Buttons' "$TARGET" 2>/dev/null && partial=1 || true
    if (( partial )); then
      echo 'PASS: prerequisites verified; partial installation detected; --install will complete or upgrade it.'
    else
      echo 'PASS: prerequisites verified; ready for first installation; no files changed.'
    fi
  fi
  exit 0
fi

if installation_complete; then
  echo 'ALREADY INSTALLED: unified DVSwitch mode buttons are complete.'
  exit 0
fi

install -o root -g root -m 755 "$tmp/dvswitch-mode-buttons.$HELPER_BASE" "$MODE_HELPER"
install -o root -g root -m 755 "$tmp/dvswitch-dmr-network.sh.$BACKEND_BASE" "$DMR_HELPER"
install -o root -g root -m 644 "$tmp/dvswitch-mode-buttons.php.$ENDPOINT_BASE" "$ENDPOINT"
install -o root -g root -m 440 "$tmp/dvswitch-mode-buttons.sudoers.$BACKEND_BASE" "$SUDOERS"

visudo -cf "$SUDOERS" >/dev/null || die 'sudoers validation failed'
php -l "$ENDPOINT" >/dev/null || die 'endpoint PHP validation failed'
bash -n "$MODE_HELPER" "$DMR_HELPER"
grep -qF 'update_state "$network"' "$DMR_HELPER" || die 'DMR state update is missing'
if grep -qF 'Analog_Bridge.ini' "$DMR_HELPER"; then
  die 'DMR helper must not modify Analog_Bridge.ini'
fi

if [[ ! -f "$PRESET_DIR/MMDVM_Bridge.BM.ini" || ! -f "$PRESET_DIR/MMDVM_Bridge.TGIF.ini" ]]; then
  bash "$tmp/dvswitch-mode-buttons.sh.$BACKEND_BASE" --install
fi

run_dashboard_revision(){
  local commit=$1
  local file=${2:-install-dashboard-buttons.sh}
  local output="$tmp/dashboard.$commit.sh"
  git show "$commit:$file" > "$output"
  chmod 755 "$output"
  bash "$output"
}

if grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test8 -->' "$TARGET"; then
  :
elif grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test7 -->' "$TARGET"; then
  run_dashboard_revision "$UPGRADE_BASE"
  run_dashboard_revision "$GREEN_BASE"
  run_dashboard_revision "$DASHBOARD_BASE" install-dashboard-buttons-refresh.sh
elif grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test6 -->' "$TARGET"; then
  run_dashboard_revision "$HORIZONTAL_BASE"
  run_dashboard_revision "$UPGRADE_BASE"
  run_dashboard_revision "$GREEN_BASE"
  run_dashboard_revision "$DASHBOARD_BASE" install-dashboard-buttons-refresh.sh
else
  run_dashboard_revision "$SEED_BASE"
  run_dashboard_revision "$HORIZONTAL_BASE"
  run_dashboard_revision "$UPGRADE_BASE"
  run_dashboard_revision "$GREEN_BASE"
  run_dashboard_revision "$DASHBOARD_BASE" install-dashboard-buttons-refresh.sh
fi

dashboard_complete || die 'final dashboard block or refresh code missing'
command -v systemctl >/dev/null 2>&1 || die 'systemctl is required to refresh Apache'
systemctl restart apache2 || die 'Apache restart failed after dashboard installation'

echo 'PASS: unified dashboard, refresh, endpoint, helper, sudoers, and BM/TGIF installer installed.'
echo 'PASS: DMR helper updates the Mods network state and does not modify Analog_Bridge.ini.'
echo 'NOTICE: If the DVSwitch dashboard was already open, refresh that browser tab (press F5) to display the new buttons.'
