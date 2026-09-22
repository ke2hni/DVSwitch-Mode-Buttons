#!/usr/bin/env bash
set -Eeuo pipefail

STATUS=/usr/share/dvswitch/include/status.php
BACKUP_DIR=/var/backups/dvswitch-mode-buttons/dmr-card-room-label
MARKER='// DVSwitch-Mode-Buttons: standalone DMR Master display v1'

[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo' >&2; exit 1; }
[[ -f "$STATUS" ]] || { echo "ERROR: missing $STATUS" >&2; exit 1; }
[[ $# -eq 1 && ( "$1" == '--check' || "$1" == '--install' ) ]] || { echo "Usage: sudo $0 {--check|--install}" >&2; exit 2; }

python3 - "$STATUS" "$BACKUP_DIR" "$MARKER" "$1" <<'PY'
import os
import re
import shutil
import sys
import tempfile
import time
from pathlib import Path

path = Path(sys.argv[1])
backup_dir = Path(sys.argv[2])
marker = sys.argv[3]
action = sys.argv[4]
raw = path.read_bytes()
nl = b'\r\n' if b'\r\n' in raw else b'\n'
text = raw.replace(b'\r\n', b'\n').decode('utf-8')

if text.count(marker) != 1:
    raise SystemExit('ERROR: expected exactly one standalone DMR card marker')
if text.count('function dvsButtonsDmrMasterDisplay($master, $abinfo) {') != 1:
    raise SystemExit('ERROR: expected exactly one standalone DMR display function')
if "return 'Room<br>'" in text:
    print('ALREADY INSTALLED: DMR card Room label is present.')
    raise SystemExit(0)

pattern = re.compile(
    r"function dvsButtonsDmrMasterDisplay\(\$master, \$abinfo\) \{.*?\n\}",
    re.S,
)
match = pattern.search(text)
if match is None:
    raise SystemExit('ERROR: standalone DMR display function structure is unsupported')
old = match.group(0)
expected = """function dvsButtonsDmrMasterDisplay($master, $abinfo) {
        $mode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        $network = ($mode === 'STFU') ? 'BM' : dvsButtonsDmrNetwork($master);
        $talkgroup = dvsButtonsDmrTalkgroup($abinfo);
        if ($talkgroup === '') { return htmlspecialchars((string)$master, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
        $name = dvsButtonsDmrName($network, $talkgroup);
        $display = ($name !== '') ? $name : 'TG '.$talkgroup;
        return htmlspecialchars($display, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}"""
if old != expected:
    raise SystemExit('ERROR: existing standalone DMR display function is not the supported v5 structure')
new = old.replace(
    "return htmlspecialchars((string)$master, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');",
    "return 'Room<br>'.htmlspecialchars((string)$master, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');",
).replace(
    "return htmlspecialchars($display, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');",
    "return 'Room<br>'.htmlspecialchars($display, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');",
)
candidate = text[:match.start()] + new + text[match.end():]
if candidate.count("return 'Room<br>'") != 2:
    raise SystemExit('ERROR: DMR Room label update was not applied exactly twice')

if action == '--check':
    print('PASS: supported DMR card v5 structure; Room label is ready to install. No files changed.')
    raise SystemExit(0)

backup_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
backup = backup_dir / ('status.php.' + time.strftime('%Y%m%d-%H%M%S'))
shutil.copy2(path, backup)
stat = path.stat()
fd, temporary = tempfile.mkstemp(dir=path.parent)
try:
    with os.fdopen(fd, 'wb') as stream:
        stream.write(candidate.replace('\n', nl.decode()).encode('utf-8'))
    os.chown(temporary, stat.st_uid, stat.st_gid)
    os.chmod(temporary, stat.st_mode & 0o7777)
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
print(f'PASS: DMR card Room label installed. Backup: {backup}')
PY

php -l "$STATUS"
echo 'PASS: DMR card Room-label update completed.'
