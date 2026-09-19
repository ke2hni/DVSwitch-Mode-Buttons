#!/usr/bin/env bash
set -Eeuo pipefail
STATUS=/usr/share/dvswitch/include/status.php
BACKUP_DIR=/var/backups/dvswitch-mode-buttons
MARKER='// DVSwitch-Mode-Buttons: DMR Master active-network display v2'
die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ -f "$STATUS" ]] || die "missing $STATUS"
python3 - "$STATUS" "$BACKUP_DIR" "$MARKER" <<'PY'
import os, shutil, sys, tempfile, time
path, backup_dir, marker = sys.argv[1:]
raw=open(path,'rb').read()
if marker.encode() in raw:
    print('ALREADY INSTALLED: DMR Master active-network display v2 is present.')
    raise SystemExit(0)
nl='\r\n' if b'\r\n' in raw else '\n'
text=raw.replace(b'\r\n',b'\n').decode()
old_heading='''function dvsModsDmrMasterHeading($master, $abinfo) {
        $state = dvsModsDmrStateRead();
        $mode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        if (isset($state['current_network']) && ($state['current_network'] === 'BM' || $state['current_network'] === 'TGIF')) {
                $network = $state['current_network'];
        } else {
                $network = dvsModsDmrNetwork($master);
        }
        return 'DMR '.$network.' Master';
}'''
new_heading='''function dvsModsDmrMasterHeading($master, $abinfo) {
        return 'DMR '.dvsModsDmrNetwork($master).' Master';
}'''
old_display="""        $network = (isset($state['current_network']) && ($state['current_network'] === 'BM' || $state['current_network'] === 'TGIF')) ? $state['current_network'] : dvsModsDmrNetwork($master);"""
new_display="""        $network = dvsModsDmrNetwork($master);"""
if text.count(old_heading) != 1: raise SystemExit(f'expected one DMR heading function; found {text.count(old_heading)}')
if text.count(old_display) != 1: raise SystemExit(f'expected one DMR display network assignment; found {text.count(old_display)}')
updated=text.replace(old_heading, marker+'\n'+new_heading, 1).replace(old_display,new_display,1)
os.makedirs(backup_dir, mode=0o700, exist_ok=True)
stamp=time.strftime('%Y%m%d-%H%M%S'); backup=os.path.join(backup_dir,'status.php.'+stamp)
shutil.copy2(path,backup)
st=os.stat(path); fd,tmp=tempfile.mkstemp(dir=os.path.dirname(path))
try:
    with os.fdopen(fd,'wb') as f: f.write(updated.replace('\n',nl).encode())
    os.chown(tmp,st.st_uid,st.st_gid); os.chmod(tmp,st.st_mode & 0o7777); os.replace(tmp,path)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print(f'PASS: DMR Master state override removed. Backup: {backup}')
PY
php -l "$STATUS"
echo 'PASS: DMR Master heading and talkgroup now follow current-mode.'
