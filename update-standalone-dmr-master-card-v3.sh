#!/usr/bin/env bash
set -Eeuo pipefail

STATUS=/usr/share/dvswitch/include/status.php
BACKUP_DIR=/var/backups/dvswitch-mode-buttons
OLD_MARKER='// DVSwitch-Mode-Buttons: standalone DMR Master display v2'
NEW_MARKER='// DVSwitch-Mode-Buttons: standalone DMR Master display v3'

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
    print('ALREADY INSTALLED: standalone DMR Master display v3 is present.')
    raise SystemExit(0)
if text.count(old_marker) != 1:
    raise SystemExit('ERROR: expected exactly one standalone DMR Master display v2')

old_heading = '''function dvsButtonsDmrMasterHeading($master, $abinfo) {
        $mode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        if ($mode === 'STFU') { return 'DMR STFU Master'; }
        $network = dvsButtonsDmrSavedNetwork();
        return 'DMR '.(($network !== '') ? $network : dvsButtonsDmrNetwork($master)).' Master';
}'''
new_heading = '''function dvsButtonsDmrMasterHeading($master, $abinfo) {
        $cardMode = dvsButtonsDmrSavedCardMode();
        if ($cardMode === 'STFU') { return 'DMR STFU Master'; }
        if ($cardMode === 'BM' || $cardMode === 'TGIF') { return 'DMR '.$cardMode.' Master'; }
        return 'DMR '.dvsButtonsDmrNetwork($master).' Master';
}'''
old_saved = '''function dvsButtonsDmrSavedNetwork() {
        $file = '/var/lib/dvswitch-mode-buttons/last-dmr-network';
        if (!is_readable($file)) { return ''; }
        $network = strtoupper(trim((string)file_get_contents($file)));
        return ($network === 'BM' || $network === 'TGIF') ? $network : '';
}'''
new_saved = '''function dvsButtonsDmrSavedNetwork() {
        $file = '/var/lib/dvswitch-mode-buttons/last-dmr-network';
        if (!is_readable($file)) { return ''; }
        $network = strtoupper(trim((string)file_get_contents($file)));
        return ($network === 'BM' || $network === 'TGIF') ? $network : '';
}

function dvsButtonsDmrSavedCardMode() {
        $file = '/var/lib/dvswitch-mode-buttons/last-dmr-card-mode';
        if (!is_readable($file)) { return ''; }
        $mode = strtoupper(trim((string)file_get_contents($file)));
        return ($mode === 'BM' || $mode === 'TGIF' || $mode === 'STFU') ? $mode : '';
}'''
old_display = '''function dvsButtonsDmrMasterDisplay($master, $abinfo) {
        $mode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        $network = ($mode === 'STFU') ? 'BM' : dvsButtonsDmrSavedNetwork();
        if ($network === '') { $network = dvsButtonsDmrNetwork($master); }
        $talkgroup = dvsButtonsDmrTalkgroup($abinfo);'''
new_display = '''function dvsButtonsDmrMasterDisplay($master, $abinfo) {
        $mode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        $cardMode = dvsButtonsDmrSavedCardMode();
        $network = ($cardMode === 'STFU') ? 'BM' : dvsButtonsDmrSavedNetwork();
        if ($network === '') { $network = dvsButtonsDmrNetwork($master); }
        $talkgroup = dvsButtonsDmrTalkgroup($abinfo);'''

for old, label in ((old_heading, 'heading'), (old_saved, 'saved-network'), (old_display, 'display')):
    if text.count(old) != 1:
        raise SystemExit(f'ERROR: expected exactly one v2 {label} block')
updated = text.replace(old_marker, new_marker, 1)
updated = updated.replace(old_heading, new_heading, 1)
updated = updated.replace(old_saved, new_saved, 1)
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
print(f'PASS: standalone DMR Master display v3 installed. Backup: {backup}')
PY

php -l "$STATUS"
echo 'PASS: DMR Master card now latches STFU/BM/TGIF across non-DMR modes.'
