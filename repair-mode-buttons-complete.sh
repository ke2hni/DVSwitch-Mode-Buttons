#!/usr/bin/env bash
set -Eeuo pipefail

HELPER=/usr/local/sbin/dvswitch-mode-buttons
DMR_HELPER=/usr/local/sbin/dvswitch-dmr-network
BACKUP_DIR=/var/backups/dvswitch-mode-buttons

[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo' >&2; exit 1; }
[[ -x ./repair-mode-buttons-display.sh ]] || { echo 'ERROR: missing repair-mode-buttons-display.sh' >&2; exit 1; }
./repair-mode-buttons-display.sh

python3 - "$HELPER" "$DMR_HELPER" "$BACKUP_DIR" <<'PY'
import os,sys,tempfile,shutil,time
for path in sys.argv[1:]:
    raw=open(path,'rb').read(); text=raw.replace(b'\r\n',b'\n').decode()
    old='echo "PASS: DVSwitch mode selected: $mode"'
    if old not in text: continue
    nl='\r\n' if b'\r\n' in raw else '\n'; st=os.stat(path); stamp=time.strftime('%Y%m%d-%H%M%S')
    backup=f'{sys.argv[3]}/{os.path.basename(path)}.{stamp}'; shutil.copy2(path,backup)
    new='if [ -t 1 ]; then echo "PASS: DVSwitch mode selected: $mode"; fi'
    text=text.replace(old,new,1); fd,tmp=tempfile.mkstemp(dir=os.path.dirname(path))
    try:
        with os.fdopen(fd,'wb') as f: f.write(text.replace('\n',nl).encode())
        os.chown(tmp,st.st_uid,st.st_gid); os.chmod(tmp,st.st_mode&0o7777); os.replace(tmp,path)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
    print(f'PASS: helper output corrected; backup: {backup}')
PY

bash -n "$HELPER" "$DMR_HELPER"
php -l /usr/share/dvswitch/dvswitch-mode-buttons.php
php -l /usr/share/dvswitch/include/status.php
echo 'PASS: complete mode-button repair verified.'
