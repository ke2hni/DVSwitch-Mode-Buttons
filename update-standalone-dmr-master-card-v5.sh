#!/usr/bin/env bash
set -Eeuo pipefail

STATUS=/usr/share/dvswitch/include/status.php
BACKUP_DIR=/var/backups/dvswitch-mode-buttons
MARKER='// DVSwitch-Mode-Buttons: standalone DMR Master display v5'

[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo' >&2; exit 1; }
[[ -f "$STATUS" ]] || { echo "ERROR: missing $STATUS" >&2; exit 1; }

python3 - "$STATUS" "$BACKUP_DIR" "$MARKER" <<'PY'
import os, shutil, sys
from datetime import datetime

status, backup_dir, marker = sys.argv[1:]
text = open(status, encoding='utf-8').read()

if marker in text:
    print('ALREADY INSTALLED: standalone DMR Master display v5 is present.')
    raise SystemExit(0)

old = 'style=\\"color:#b5651d;font-weight: bold\\"'
new = 'style=\\"color:#b5651d;font-weight: bold;white-space:normal;word-break:normal;overflow-wrap:anywhere;text-align:center;\\"'
needle = 'dvsButtonsDmrMasterDisplay($dmrMasterHost, $abinfo)'
positions = [i for i in range(len(text)) if text.startswith(needle, i)]
if len(positions) != 1:
    raise SystemExit(f'ERROR: expected exactly one active standalone DMR display call; found {len(positions)}')

line_start = text.rfind('\n', 0, positions[0]) + 1
line_end = text.find('\n', positions[0])
if line_end < 0:
    line_end = len(text)
line = text[line_start:line_end]
if old not in line:
    raise SystemExit('ERROR: active DMR display line does not contain the expected standalone span style')

text = text[:line_start] + line.replace(old, new, 1) + text[line_end:]
stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
backup = os.path.join(backup_dir, f'status.php.{stamp}')
os.makedirs(backup_dir, mode=0o700, exist_ok=True)
shutil.copy2(status, backup)
tmp = status + '.dvswitch-mode-buttons-v5.tmp'
with open(tmp, 'w', encoding='utf-8', newline='') as f:
    f.write(text)
os.chmod(tmp, os.stat(status).st_mode & 0o777)
os.replace(tmp, status)
print(f'PASS: DMR Master wrapping restored. Backup: {backup}')
PY

php -l "$STATUS"
grep -q 'white-space:normal;word-break:normal;overflow-wrap:anywhere;text-align:center' "$STATUS" || {
    echo 'ERROR: wrapping style was not verified in status.php' >&2
    exit 1
}
echo 'PASS: DMR Master friendly names now wrap within the card.'
