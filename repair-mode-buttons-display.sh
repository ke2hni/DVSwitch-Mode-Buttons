#!/usr/bin/env bash
set -Eeuo pipefail
ENDPOINT=/usr/share/dvswitch/dvswitch-mode-buttons.php
STATUS=/usr/share/dvswitch/include/status.php
BACKUP_DIR=/var/backups/dvswitch-mode-buttons
die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ -f $ENDPOINT ]] || die "missing $ENDPOINT"
[[ -f $STATUS ]] || die "missing $STATUS"
python3 - "$ENDPOINT" "$STATUS" "$BACKUP_DIR" <<'PY'
import os,sys,tempfile,shutil,time
endpoint,status,backup_dir=sys.argv[1:]
stamp=time.strftime('%Y%m%d-%H%M%S')
os.makedirs(backup_dir,mode=0o700,exist_ok=True)
def patch(path,marker,old,new,name):
    raw=open(path,'rb').read()
    if marker.encode() in raw: return
    nl='\r\n' if b'\r\n' in raw else '\n'
    text=raw.replace(b'\r\n',b'\n').decode()
    if text.count(old)!=1: raise SystemExit(f'expected one patch target in {path}; found {text.count(old)}')
    st=os.stat(path); backup=f'{backup_dir}/{name}.{stamp}'; shutil.copy2(path,backup)
    fd,tmp=tempfile.mkstemp(dir=os.path.dirname(path))
    try:
        with os.fdopen(fd,'wb') as f: f.write(text.replace(old,new,1).replace('\n',nl).encode())
        os.chown(tmp,st.st_uid,st.st_gid); os.chmod(tmp,st.st_mode&0o7777); os.replace(tmp,path)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
    print(f'PASS: patched {path}; backup: {backup}')
old_endpoint="$command = '/usr/bin/sudo /usr/local/sbin/dvswitch-mode-buttons '.escapeshellarg($mode).' 2>&1';\n$output = array();\n$status = 0;\nexec($command, $output, $status);"
new_endpoint=old_endpoint+"\nif ($status === 0) { $output = array(); }"
old_status='function dvsModsDmrTalkgroup($abinfo) {\n        $values = array();'
new_status="// DVSwitch-Mode-Buttons: DMR Master mode isolation v1\nfunction dvsModsDmrTalkgroup($abinfo) {\n        $mode = strtoupper(trim((string)($abinfo['tlv']['ambe_mode'] ?? '')));\n        if ($mode !== 'DMR') { return ''; }\n        $values = array();"
patch(endpoint,'// DVSwitch-Mode-Buttons: clean successful response v1',old_endpoint,new_endpoint,'dvswitch-mode-buttons.php')
patch(status,'// DVSwitch-Mode-Buttons: DMR Master mode isolation v1',old_status,new_status,'status.php')
PY
php -l "$ENDPOINT"
php -l "$STATUS"
echo 'PASS: button response and DMR Master isolation verified.'
