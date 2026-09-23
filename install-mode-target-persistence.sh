#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=/opt/MMDVM_Bridge
SCRIPT=$ROOT/dvswitch.sh
MODE_HELPER=/usr/local/sbin/dvswitch-mode-buttons
DMR_HELPER=/usr/local/sbin/dvswitch-dmr-network
TARGET_HELPER=/usr/local/sbin/dvswitch-mode-targets
STATE_DIR=/var/lib/dvswitch-mode-buttons
BACKUP_DIR=/var/backups/dvswitch-mode-buttons
MARKER='# DVSwitch-Mode-Buttons: per-mode target persistence v1'

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ -f $SCRIPT ]] || die "missing $SCRIPT"
[[ -f dvswitch-mode-targets ]] || die 'run from the repository directory'
[[ -f dvswitch-mode-buttons ]] || die 'missing repository dvswitch-mode-buttons'

install -d "$STATE_DIR"
chown root:root "$STATE_DIR"
chmod 755 "$STATE_DIR"
install -d -m 700 -o root -g root "$BACKUP_DIR"
stamp=$(date +%Y%m%d-%H%M%S)
if ! grep -qF "$MARKER" "$SCRIPT"; then
  cp -a "$SCRIPT" "$BACKUP_DIR/dvswitch.sh.$stamp"
fi
cp -a "$MODE_HELPER" "$BACKUP_DIR/dvswitch-mode-buttons.$stamp" 2>/dev/null || true
cp -a "$DMR_HELPER" "$BACKUP_DIR/dvswitch-dmr-network.$stamp" 2>/dev/null || true
install -o root -g root -m 755 dvswitch-mode-targets "$TARGET_HELPER"
install -o root -g root -m 755 dvswitch-mode-buttons "$MODE_HELPER"
# Keep the historical command path as a compatibility symlink to the unified mode helper.
link_tmp="${DMR_HELPER}.tmp.$$"
rm -f "$link_tmp"
ln -s "$MODE_HELPER" "$link_tmp"
mv -Tf "$link_tmp" "$DMR_HELPER"

python3 - "$SCRIPT" "$MARKER" <<'PY'
import os, sys, tempfile

path, marker = sys.argv[1:]
with open(path, 'rb') as f:
    raw = f.read()
newline = b'\r\n' if b'\r\n' in raw else b'\n'
newline = newline.decode()
text = raw.replace(b'\r\n', b'\n').decode()
block = '''    if [ "${#}" -eq 0 ]; then
        getABInfoValue last_tune
    else
        remoteControlCommand "txTg=$1"
        # DVSwitch-Mode-Buttons: per-mode target persistence v1
        if [ -r /var/lib/dvswitch-mode-buttons/current-mode ]; then
            mode=$(tr -d '[:space:]' < /var/lib/dvswitch-mode-buttons/current-mode)
            case "$mode" in
                BM|TGIF|STFU|YSF|P25|NXDN|DSTAR)
                    /usr/local/sbin/dvswitch-mode-targets save "$mode" "$1" >/dev/null || true
                    ;;
            esac
        fi
    fi'''
if marker.encode() in raw:
    raise SystemExit(0)
old = '''    if [ $# -eq 0 ]; then
        getABInfoValue last_tune
    else
        remoteControlCommand "txTg=$1"
    fi'''
if text.count(old) != 1:
    raise SystemExit(f'expected one original tune block; found {text.count(old)}')
new = block.replace('    if [ "${#}" -eq 0 ]; then', '    if [ $# -eq 0 ]; then')
text = text.replace(old, new, 1)
st = os.stat(path)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
try:
    with os.fdopen(fd, 'wb') as f:
        f.write(text.replace('\n', newline).encode())
    os.chown(tmp, st.st_uid, st.st_gid)
    os.chmod(tmp, st.st_mode & 0o7777)
    os.replace(tmp, path)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
PY

python3 - "$MODE_HELPER" <<'PY'
import os, sys, tempfile

for path in sys.argv[1:]:
    with open(path, 'rb') as f: raw = f.read()
    if b'per-mode target persistence v1' in raw: continue
    nl = b'\r\n' if b'\r\n' in raw else b'\n'
    nl = nl.decode()
    text = raw.replace(b'\r\n', b'\n').decode()
    if path.endswith('dvswitch-mode-buttons'):
        if b'dvswitch-mode-targets get "$mode"' in raw:
            continue
        old = "printf '%s\\n' \"$mode\" > \"$STATE_FILE\"\nchown root:root \"$STATE_FILE\"\nchmod 600 \"$STATE_FILE\"\necho \"PASS: DVSwitch mode selected: $mode\""
        new = old + '''
if [ -x /usr/local/sbin/dvswitch-mode-targets ]; then
  target=$(/usr/local/sbin/dvswitch-mode-targets get "$mode" 2>/dev/null || true)
  [ -n "$target" ] && "$MODE_CMD" tune "$target"
fi'''
    if text.count(old) != 1: raise SystemExit(f'expected one patch target in {path}; found {text.count(old)}')
    text = text.replace(old, new, 1)
    st = os.stat(path); fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, 'wb') as f: f.write(text.replace('\n', nl).encode())
        os.chown(tmp, st.st_uid, st.st_gid); os.chmod(tmp, st.st_mode & 0o7777); os.replace(tmp, path)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
PY

php -l /usr/share/dvswitch/include/status.php >/dev/null || die 'dashboard PHP validation failed'
bash -n "$SCRIPT" "$MODE_HELPER" "$TARGET_HELPER"
echo "PASS: per-mode target persistence installed. Backup: $BACKUP_DIR (timestamp $stamp)"
