#!/usr/bin/env bash
set -u
TARGET="/usr/share/dvswitch/index.php"
[[ $EUID -eq 0 ]] || { echo "ERROR: run with sudo" >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "ERROR: missing $TARGET" >&2; exit 1; }
python3 - "$TARGET" <<'PY'
import os, re, shutil, sys
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text()
marker='<!-- DVSwitch-Mode-Buttons 1.0.0-test6 -->'
a=s.find(marker)
if a < 0: raise SystemExit('ERROR: installed mode-button block not found')
b=s.find('</script>',a)
if b < 0: raise SystemExit('ERROR: installed mode-button script end not found')
b += len('</script>')
old=s[a:b]
new='''<!-- DVSwitch-Mode-Buttons 1.0.0-test7 -->
<div id="dvs-mode-buttons" aria-label="Select Mode"><div class="dvs-mode-buttons-title">Select Mode</div>
<button type="button" class="button link" data-mode="BM">BM</button><button type="button" class="button link" data-mode="TGIF">TGIF</button><button type="button" class="button link" data-mode="STFU">STFU</button><button type="button" class="button link" data-mode="YSF">YSF</button><button type="button" class="button link" data-mode="P25">P25</button><button type="button" class="button link" data-mode="NXDN">NXDN</button><button type="button" class="button link" data-mode="DSTAR">D-Star</button></div>
<style>#dvs-mode-buttons{text-align:center;margin:4px auto 8px}#dvs-mode-buttons .dvs-mode-buttons-title{font-weight:bold;margin-bottom:2px}#dvs-mode-buttons button{min-width:72px;height:32px;padding:4px 10px}#dvs-mode-buttons button.selected{background-color:#356244}#dvs-mode-buttons button:disabled{opacity:.65}</style>
<script>(function(){const box=document.getElementById('dvs-mode-buttons'),buttons=[...box.querySelectorAll('button')];buttons.forEach(b=>b.addEventListener('click',async()=>{buttons.forEach(x=>x.disabled=true);try{const r=await fetch('/dvswitch/dvswitch-mode-buttons.php?mode='+encodeURIComponent(b.dataset.mode)),j=await r.json();if(!j.ok)throw new Error(j.output||'switch failed');buttons.forEach(x=>x.classList.toggle('selected',x===b));}catch(e){alert('Mode switch failed: '+e.message)}finally{buttons.forEach(x=>x.disabled=false)}}))})();</script>'''
s=s[:a]+s[b:]
anchor=re.search(r'<div style="margin-top:8px;">',s,re.I)
if not anchor: raise SystemExit('ERROR: RX Monitor anchor not found')
s=s[:anchor.start()]+new+'\n'+s[anchor.start():]
tmp=p.with_name(p.name+'.tmp-mode-buttons'); tmp.write_text(s); shutil.copystat(p,tmp); os.chown(tmp,os.stat(p).st_uid,os.stat(p).st_gid); os.replace(tmp,p)
print('PASS: dashboard buttons moved above RX Monitor and centered.')
PY
