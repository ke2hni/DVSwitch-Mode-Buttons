#!/usr/bin/env bash
set -Eeuo pipefail

AB_ROOT=/opt/Analog_Bridge
MB_ROOT=/opt/MMDVM_Bridge
AB="$AB_ROOT/Analog_Bridge.ini"
MB="$MB_ROOT/MMDVM_Bridge.ini"
PRESET_DIR=/etc/dvswitch-mode-buttons/dmr-presets
SELECTOR=/usr/local/sbin/dvswitch-select-dmr-starttg
UNIT=/etc/systemd/system/dvswitch-dmr-starttg.service

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ -f "$AB" && -f "$MB" ]] || die 'required DVSwitch INI file is missing'

network="$(python3 - "$MB" <<'PY'
import re, sys
text=open(sys.argv[1], encoding='utf-8').read()
m=re.search(r'(?ms)^\[DMR Network\]\s*\n(.*?)(?=^\[|\Z)', text)
if m:
    a=re.search(r'(?im)^\s*Address\s*=\s*([^;#\r\n]+)', m.group(1))
    if a: print(a.group(1).strip())
PY
)"
case "$network" in
  *brandmeister*|*repeater.net*|*3102*|*3104*) current=BM ;;
  *tgif*) current=TGIF ;;
  *) die "could not identify current BM/TGIF network from MMDVM_Bridge.ini: ${network:-none}" ;;
esac
alternate=TGIF; [[ "$current" == TGIF ]] && alternate=BM

start_count="$(python3 - "$AB" <<'PY'
import re, sys
t=open(sys.argv[1], encoding='utf-8').read()
m=re.search(r'(?ms)^\[AMBE_AUDIO\]\s*\n(.*?)(?=^\[|\Z)', t)
print(len(re.findall(r'(?im)^\s*txTg\s*=', m.group(1))) if m else 0)
PY
)"
[[ "$start_count" == 1 ]] || die "expected exactly one txTg setting in [AMBE_AUDIO]; found $start_count"
current_tg="$(sed -nE '/^\[AMBE_AUDIO\][[:space:]]*$/,/^\[/ s/^[[:space:]]*txTg[[:space:]]*=[[:space:]]*([^;#[:space:]]+).*$/\1/ip' "$AB")"
[[ -n "$current_tg" ]] || die 'current txTg is empty'
read -r -p "$alternate txTg for boot: " alternate_tg
[[ "$alternate_tg" =~ ^[0-9]+$ ]] || die 'txTg must be numeric'

install -d -m 700 -o root -g root "$PRESET_DIR"
stamp="$(date +%Y%m%d-%H%M%S)"
backup="$PRESET_DIR/install-$stamp"
install -d -m 700 -o root -g root "$backup"
cp -p "$AB" "$backup/Analog_Bridge.ini"

export AB PRESET_DIR current alternate alternate_tg
python3 - <<'PY'
import os, re, shutil, tempfile
ab=os.environ['AB']; out=os.environ['PRESET_DIR']
current=os.environ['current']; alternate=os.environ['alternate']; alt_tg=os.environ['alternate_tg']
data=open(ab, encoding='utf-8', newline='').read()
section=re.search(r'(?ms)^\[AMBE_AUDIO\]\s*\n(.*?)(?=^\[|\Z)', data)
if not section: raise SystemExit('missing [AMBE_AUDIO]')
line=re.compile(r'^(\s*txTg\s*=\s*)([^;#\r\n]+)(.*)$', re.I|re.M)
if len(line.findall(section.group(1))) != 1: raise SystemExit('expected exactly one txTg in [AMBE_AUDIO]')
def write(name, value):
    result=data
    if name == alternate:
        body=line.sub(lambda m: m.group(1)+value+m.group(3), section.group(1), count=1)
        result=data[:section.start(1)]+body+data[section.end(1):]
    fd,tmp=tempfile.mkstemp(dir=out); os.close(fd)
    with open(tmp,'w',encoding='utf-8',newline='') as f: f.write(result)
    shutil.copystat(ab,tmp); st=os.stat(ab); os.chown(tmp,st.st_uid,st.st_gid); os.replace(tmp,os.path.join(out,'Analog_Bridge.'+name+'.ini'))
write(current, None); write(alternate, alt_tg)
PY

install -m 755 -o root -g root /dev/stdin "$SELECTOR" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
MB=/opt/MMDVM_Bridge/MMDVM_Bridge.ini
AB=/opt/Analog_Bridge/Analog_Bridge.ini
DIR=/etc/dvswitch-mode-buttons/dmr-presets
[[ -f "$MB" && -f "$AB" ]] || { echo 'ERROR: required INI file missing' >&2; exit 1; }
net="$(python3 - "$MB" <<'PY'
import re,sys
t=open(sys.argv[1],encoding='utf-8').read(); m=re.search(r'(?ms)^\[DMR Network\]\s*\n(.*?)(?=^\[|\Z)',t)
a=re.search(r'(?im)^\s*Address\s*=\s*([^;#\r\n]+)',m.group(1)) if m else None
print(a.group(1).strip() if a else '')
PY
)"
case "$net" in *brandmeister*|*repeater.net*|*3102*|*3104*) p="$DIR/Analog_Bridge.BM.ini"; n=BM;; *tgif*) p="$DIR/Analog_Bridge.TGIF.ini"; n=TGIF;; *) echo "ERROR: unknown DMR network: ${net:-none}" >&2; exit 1;; esac
[[ -f "$p" ]] || { echo "ERROR: missing $p" >&2; exit 1; }
install -m "$(stat -c %a "$AB")" -o "$(stat -c %u "$AB")" -g "$(stat -c %g "$AB")" "$p" "$AB"
echo "PASS: selected $n Analog_Bridge txTg preset."
SH

install -m 644 -o root -g root /dev/stdin "$UNIT" <<'UNIT'
[Unit]
Description=Select the BM/TGIF Analog_Bridge txTg preset
Before=analog_bridge.service
Before=mmdvm_bridge.service
Wants=analog_bridge.service
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/dvswitch-select-dmr-starttg
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable dvswitch-dmr-starttg.service >/dev/null
echo "PASS: DMR boot txTg selector installed."
echo "Current network: $current; current txTg: $current_tg"
echo "Alternate network: $alternate; alternate txTg: $alternate_tg"
echo "Presets: $PRESET_DIR"
