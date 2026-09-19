#!/usr/bin/env bash
set -Eeuo pipefail

STATUS=/usr/share/dvswitch/include/status.php
BACKUP_DIR=/var/backups/dvswitch-mode-buttons
OLD_MARKER='// DVSwitch-Mode-Buttons: standalone DMR Master display v3'
NEW_MARKER='// DVSwitch-Mode-Buttons: standalone DMR Master display v4'

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ -f "$STATUS" ]] || die "missing $STATUS"

python3 - "$STATUS" "$BACKUP_DIR" "$OLD_MARKER" "$NEW_MARKER" <<'PY'
import os, shutil, sys, tempfile, time
from pathlib import Path

path = Path(sys.argv[1]); backup_dir = Path(sys.argv[2])
old_marker, new_marker = sys.argv[3:]
text = path.read_text(encoding='utf-8')

if text.count(new_marker) == 1:
    print('ALREADY INSTALLED: standalone DMR Master display v4 is present.')
    raise SystemExit(0)
if text.count(old_marker) != 1:
    raise SystemExit('ERROR: expected exactly one standalone DMR Master display v3')

old_heading = '''function dvsButtonsDmrMasterHeading($master, $abinfo) {
        $cardMode = dvsButtonsDmrSavedCardMode();
        if ($cardMode === 'STFU') { return 'DMR STFU Master'; }
        if ($cardMode === 'BM' || $cardMode === 'TGIF') { return 'DMR '.$cardMode.' Master'; }
        return 'DMR '.dvsButtonsDmrNetwork($master).' Master';
}'''
new_heading = '''function dvsButtonsDmrMasterHeading($master, $abinfo) {
        $liveMode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        if ($liveMode === 'STFU') { return 'DMR STFU Master'; }
        $cardMode = dvsButtonsDmrSavedCardMode();
        if ($cardMode === 'STFU') { return 'DMR STFU Master'; }
        if ($cardMode === 'BM' || $cardMode === 'TGIF') { return 'DMR '.$cardMode.' Master'; }
        return 'DMR '.dvsButtonsDmrNetwork($master).' Master';
}'''
old_display = '''function dvsButtonsDmrMasterDisplay($master, $abinfo) {
        $mode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        $cardMode = dvsButtonsDmrSavedCardMode();
        $network = ($cardMode === 'STFU') ? 'BM' : dvsButtonsDmrSavedNetwork();
        if ($network === '') { $network = dvsButtonsDmrNetwork($master); }
        $talkgroup = dvsButtonsDmrTalkgroup($abinfo);'''
new_display = '''function dvsButtonsDmrMasterDisplay($master, $abinfo) {
        $mode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        $cardMode = dvsButtonsDmrSavedCardMode();
        $network = ($mode === 'STFU' || $cardMode === 'STFU') ? 'BM' : dvsButtonsDmrSavedNetwork();
        if ($network === '') { $network = dvsButtonsDmrNetwork($master); }
        $talkgroup = dvsButtonsDmrTalkgroup($abinfo);'''

if text.count(old_heading) != 1 or text.count(old_display) != 1:
    raise SystemExit('ERROR: expected exactly one v3 heading and display function')

updated = text.replace(old_marker, new_marker, 1)
updated = updated.replace(old_heading, new_heading, 1)
updated = updated.replace(old_display, new_display, 1)

backup_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
backup = backup_dir / ('status.php.' + time.strftime('%Y%m%d-%H%M%S'))
shutil.copy2(path, backup)
stat = path.stat(); fd, temporary = tempfile.mkstemp(dir=path.parent)
try:
    with os.fdopen(fd, 'w', encoding='utf-8', newline='') as stream:
        stream.write(updated)
    os.chown(temporary, stat.st_uid, stat.st_gid)
    os.chmod(temporary, stat.st_mode & 0o7777)
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary): os.unlink(temporary)
print(f'PASS: standalone DMR Master display v4 installed. Backup: {backup}')
PY

php -l "$STATUS"
echo 'PASS: live STFU detection restored; saved state remains a fallback.'
