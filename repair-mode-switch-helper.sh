#!/usr/bin/env bash
set -Eeuo pipefail
HELPER=/usr/local/sbin/dvswitch-mode-buttons
BACKUP_DIR=/var/backups/dvswitch-mode-buttons
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo' >&2; exit 1; }
[[ -f $HELPER ]] || { echo "ERROR: missing $HELPER" >&2; exit 1; }
python3 - "$HELPER" "$BACKUP_DIR" <<'PY'
import os,sys,tempfile,shutil,time
path,backup_dir=sys.argv[1:]
raw=open(path,'rb').read(); text=raw.replace(b'\r\n',b'\n').decode()
old1='    "$NETWORK_HELPER" "$mode"\n    install -d -m 700 -o root -g root "$STATE_DIR"'
new1='    if ! "$NETWORK_HELPER" "$mode"; then\n      exit 1\n    fi\n    install -d -m 700 -o root -g root "$STATE_DIR"'
old2='  target=$(/usr/local/sbin/dvswitch-mode-targets get "$mode" 2>/dev/null || true)\n  [ -n "$target" ] && "$MODE_CMD" tune "$target"'
new2='  target=$(/usr/local/sbin/dvswitch-mode-targets get "$mode" 2>/dev/null || true)\n  if [ -n "$target" ]; then\n    "$MODE_CMD" tune "$target" || true\n  fi'
if text.count(old1)!=1 or text.count(old2)!=1: raise SystemExit(f'expected one helper target; found network={text.count(old1)} restore={text.count(old2)}')
nl='\r\n' if b'\r\n' in raw else '\n'; st=os.stat(path); os.makedirs(backup_dir,mode=0o700,exist_ok=True)
backup=f'{backup_dir}/dvswitch-mode-buttons.{time.strftime("%Y%m%d-%H%M%S")}'; shutil.copy2(path,backup)
text=text.replace(old1,new1,1).replace(old2,new2,1); fd,tmp=tempfile.mkstemp(dir=os.path.dirname(path))
try:
    with os.fdopen(fd,'wb') as f: f.write(text.replace('\n',nl).encode())
    os.chown(tmp,st.st_uid,st.st_gid); os.chmod(tmp,st.st_mode&0o7777); os.replace(tmp,path)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print('PASS: mode helper corrected. Backup: '+backup)
PY
bash -n "$HELPER"
echo 'PASS: mode helper syntax validated.'
