#!/usr/bin/env bash
set -u
TARGET="/usr/share/dvswitch/index.php"
[[ $EUID -eq 0 ]] || { echo "ERROR: run with sudo" >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "ERROR: missing $TARGET" >&2; exit 1; }
python3 - "$TARGET" <<'PY'
import os, re, shutil, sys
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text()
a=s.find('<!-- DVSwitch-Mode-Buttons 1.0.0-test7 -->')
if a < 0: raise SystemExit('ERROR: installed test7 mode-button block not found')
b=s.find('</script>',a)
if b < 0: raise SystemExit('ERROR: installed mode-button script end not found')
b += len('</script>')
block=s[a:b]
updated=block.replace('background-color:#356244','background-color:#00b000')
if updated == block: raise SystemExit('ERROR: selected-color rule not found')
tmp=p.with_name(p.name+'.tmp-mode-buttons'); tmp.write_text(s[:a]+updated+s[b:]); shutil.copystat(p,tmp); os.chown(tmp,os.stat(p).st_uid,os.stat(p).st_gid); os.replace(tmp,p)
print('PASS: selected mode-button color changed to #00b000.')
PY
