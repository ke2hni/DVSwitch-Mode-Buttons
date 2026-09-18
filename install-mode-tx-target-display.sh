#!/usr/bin/env bash
set -Eeuo pipefail

STATUS=/usr/share/dvswitch/include/status.php
BACKUP_DIR=/var/backups/dvswitch-mode-buttons
MARKER='// DVSwitch-Mode-Buttons: saved numeric Tx TG/Ref display v1'

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ -f $STATUS ]] || die "missing $STATUS"

python3 - "$STATUS" "$MARKER" "$BACKUP_DIR" <<'PY'
import os, sys, tempfile, shutil, time

path, marker, backup_dir = sys.argv[1:]
with open(path, 'rb') as f:
    raw = f.read()
if marker.encode() in raw:
    print('PASS: numeric Tx TG/Ref display is already installed.')
    raise SystemExit(0)

newline = '\r\n' if b'\r\n' in raw else '\n'
text = raw.replace(b'\r\n', b'\n').decode()
target = '    echo "<table style=\\"margin-top:4px;\\">\\n";'
if text.count(target) != 1:
    raise SystemExit(f'expected one Analog Bridge Info render target; found {text.count(target)}')

insert = '''    // DVSwitch-Mode-Buttons: saved numeric Tx TG/Ref display v1
    $savedTxTarget = '';
    $savedModeFile = '/var/lib/dvswitch-mode-buttons/current-mode';
    $savedTargetsFile = '/var/lib/dvswitch-mode-buttons/mode-targets.json';
    if (is_readable($savedModeFile) && is_readable($savedTargetsFile)) {
        $savedMode = strtoupper(trim((string)file_get_contents($savedModeFile)));
        $savedTargets = json_decode((string)file_get_contents($savedTargetsFile), true);
        if (is_array($savedTargets) && isset($savedTargets[$savedMode]['target'])) {
            $candidate = trim((string)$savedTargets[$savedMode]['target']);
            if ($candidate !== '') { $savedTxTarget = $candidate; }
        }
    }
    if ($savedTxTarget !== '') { $txValue = $savedTxTarget; }
'''
text = text.replace(target, insert + target, 1)
os.makedirs(backup_dir, mode=0o700, exist_ok=True)
st = os.stat(path)
stamp = time.strftime('%Y%m%d-%H%M%S')
backup = os.path.join(backup_dir, 'status.php.' + stamp)
shutil.copy2(path, backup)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
try:
    with os.fdopen(fd, 'wb') as f:
        f.write(text.replace('\n', newline).encode())
    os.chown(tmp, st.st_uid, st.st_gid)
    os.chmod(tmp, st.st_mode & 0o7777)
    os.replace(tmp, path)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print('PASS: numeric Tx TG/Ref display installed. Backup: ' + backup)
PY

php -l "$STATUS"
