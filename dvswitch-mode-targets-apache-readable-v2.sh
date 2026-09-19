#!/usr/bin/env bash
set -Eeuo pipefail
STATE_DIR=/var/lib/dvswitch-mode-buttons
STATE=$STATE_DIR/mode-targets.json
die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ $# -ge 2 ]] || die 'usage: save MODE TARGET | get MODE'
mode="${2:-}"
case "$mode" in BM|TGIF|STFU|YSF|P25|NXDN|DSTAR) ;; *) die 'unsupported mode';; esac
case "$1" in
  save) [[ $# -eq 3 ]] || die 'usage: save MODE TARGET'; target="$3"; [[ -n "$target" ]] || die 'target is empty' ;;
  get) [[ $# -eq 2 ]] || die 'usage: get MODE' ;;
  *) die 'usage: save MODE TARGET | get MODE' ;;
esac
install -d "$STATE_DIR"
chown root:root "$STATE_DIR"
chmod 755 "$STATE_DIR"
python3 - "$1" "$mode" "${target:-}" "$STATE" <<'PY'
import json, os, sys, tempfile
op, mode, target, path = sys.argv[1:]
data={m:{"target":""} for m in ("BM","TGIF","STFU","YSF","P25","NXDN","DSTAR")}
if os.path.exists(path):
    with open(path, encoding='utf-8') as f: old=json.load(f)
    for m in data:
        if isinstance(old.get(m), dict) and isinstance(old[m].get('target'), str): data[m]=old[m]
if op == 'save':
    data[mode]={"target":target}
    fd,tmp=tempfile.mkstemp(dir=os.path.dirname(path)); os.close(fd)
    with open(tmp,'w',encoding='utf-8') as f: json.dump(data,f,indent=2); f.write('\n')
    os.chmod(tmp,0o600); os.replace(tmp,path); print(f'PASS: saved {mode} target: {target}')
else: print(data[mode]['target'])
PY
