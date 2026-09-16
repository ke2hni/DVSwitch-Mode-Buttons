#!/usr/bin/env bash
set -u

TARGET="/usr/share/dvswitch/index.php"
MARKER="<!-- DVSwitch-Mode-Buttons 1.0.0-test6 -->"
[[ $EUID -eq 0 ]] || { echo "ERROR: run with sudo" >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "ERROR: missing $TARGET" >&2; exit 1; }

python3 - "$TARGET" "$MARKER" <<'PY'
import os, re, shutil, sys
from pathlib import Path
path=Path(sys.argv[1]); marker=sys.argv[2]; data=path.read_text()
if marker in data:
    print('ALREADY INSTALLED: dashboard mode buttons are present.'); raise SystemExit(0)
block='''<!-- DVSwitch-Mode-Buttons 1.0.0-test6 -->
<div id="dvs-mode-buttons" aria-label="Select Mode"><div class="dvs-mode-buttons-title">Select Mode</div>
<button type="button" data-mode="BM">BM</button><button type="button" data-mode="TGIF">TGIF</button>
<button type="button" data-mode="STFU">STFU</button><button type="button" data-mode="YSF">YSF</button>
<button type="button" data-mode="P25">P25</button><button type="button" data-mode="NXDN">NXDN</button>
<button type="button" data-mode="DSTAR">D-Star</button></div>
<style>#dvs-mode-buttons{position:fixed;z-index:30;left:8px;top:50%;transform:translateY(-50%);width:112px;text-align:center}#dvs-mode-buttons .dvs-mode-buttons-title{font-weight:bold;margin-bottom:8px;white-space:nowrap}#dvs-mode-buttons button{display:block;width:112px;height:32px;margin:4px 0;padding:0;line-height:30px;text-align:center;cursor:pointer}#dvs-mode-buttons button.selected{background:#356244;color:#fff}</style>
<script>(function(){const box=document.getElementById('dvs-mode-buttons'),buttons=[...box.querySelectorAll('button')];buttons.forEach(b=>b.addEventListener('click',async()=>{buttons.forEach(x=>x.disabled=true);try{const r=await fetch('/dvswitch/dvswitch-mode-buttons.php?mode='+encodeURIComponent(b.dataset.mode)),j=await r.json();if(!j.ok)throw new Error(j.output||'switch failed');buttons.forEach(x=>x.classList.toggle('selected',x===b));}catch(e){alert('Mode switch failed: '+e.message)}finally{buttons.forEach(x=>x.disabled=false)}}))})();</script>
'''
match=re.search(r'</body>',data,re.I)
if not match: raise SystemExit('ERROR: </body> anchor not found')
data=data[:match.start()]+block+data[match.start():]
tmp=path.with_name(path.name+'.tmp-mode-buttons'); tmp.write_text(data); shutil.copystat(path,tmp); os.chown(tmp,os.stat(path).st_uid,os.stat(path).st_gid); os.replace(tmp,path)
print('PASS: dashboard mode buttons installed.')
PY
