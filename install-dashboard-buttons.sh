#!/usr/bin/env bash
set -u
TARGET="/usr/share/dvswitch/index.php"
[[ $EUID -eq 0 ]] || { echo "ERROR: run with sudo" >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "ERROR: missing $TARGET" >&2; exit 1; }
python3 - "$TARGET" <<'PY'
import os, shutil, sys
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text()
a=s.find('<!-- DVSwitch-Mode-Buttons 1.0.0-test7 -->')
if a < 0: raise SystemExit('ERROR: installed test7 mode-button block not found')
b=s.find('</script>',a)
if b < 0: raise SystemExit('ERROR: installed mode-button script end not found')
b += len('</script>')
block=s[a:b]
old='background-color:#00b000'; new='background-color:#008000'
if old not in block: raise SystemExit('ERROR: current selected-color rule not found')
block=block.replace(old,new,1)
tmp=p.with_name(p.name+'.tmp-mode-buttons'); tmp.write_text(s[:a]+block+s[b:]); shutil.copystat(p,tmp); os.chown(tmp,os.stat(p).st_uid,os.stat(p).st_gid); os.replace(tmp,p)
print('PASS: selected mode-button color now matches RX Monitor (#008000).')
PY
