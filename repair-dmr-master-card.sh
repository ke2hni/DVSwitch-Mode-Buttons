#!/usr/bin/env bash
set -Eeuo pipefail
STATUS=/usr/share/dvswitch/include/status.php
BACKUP_DIR=/var/backups/dvswitch-mode-buttons
MARKER='// DVSwitch-Mode-Buttons: DMR Master active-network display v1'
die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ -f "$STATUS" ]] || die "missing $STATUS"
python3 - "$STATUS" "$BACKUP_DIR" "$MARKER" <<'PY'
import os, shutil, sys, tempfile, time
path, backup_dir, marker = sys.argv[1:]
raw=open(path,'rb').read()
if marker.encode() in raw:
    print('ALREADY INSTALLED: DMR Master active-network display is present.')
    raise SystemExit(0)
nl='\r\n' if b'\r\n' in raw else '\n'
text=raw.replace(b'\r\n',b'\n').decode()
old='''function dvsModsDmrNetwork($master) {
        $master = strtoupper(str_replace('_', ' ', (string)$master));
        if (strpos($master, 'TGIF') !== false) { return 'TGIF'; }
        return 'BM';
}'''
new='''function dvsModsDmrNetwork($master) {
        $modeFile = '/var/lib/dvswitch-mode-buttons/current-mode';
        if (is_readable($modeFile)) {
                $mode = strtoupper(trim((string)file_get_contents($modeFile)));
                if ($mode === 'BM' || $mode === 'TGIF') { return $mode; }
        }
        $master = strtoupper(str_replace('_', ' ', (string)$master));
        if (strpos($master, 'TGIF') !== false) { return 'TGIF'; }
        return 'BM';
}'''
if text.count(old) != 1:
    raise SystemExit(f'expected one DMR network function; found {text.count(old)}')
os.makedirs(backup_dir, mode=0o700, exist_ok=True)
stamp=time.strftime('%Y%m%d-%H%M%S')
backup=os.path.join(backup_dir,'status.php.'+stamp)
shutil.copy2(path,backup)
st=os.stat(path); fd,tmp=tempfile.mkstemp(dir=os.path.dirname(path))
try:
    updated=text.replace(old, marker+'\n'+new, 1)
    with os.fdopen(fd,'wb') as f: f.write(updated.replace('\n',nl).encode())
    os.chown(tmp,st.st_uid,st.st_gid); os.chmod(tmp,st.st_mode & 0o7777); os.replace(tmp,path)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print(f'PASS: DMR Master active-network display installed. Backup: {backup}')
PY
php -l "$STATUS"
echo 'PASS: DMR Master card now follows BM/TGIF current-mode state.'
