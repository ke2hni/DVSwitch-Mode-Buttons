#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="1.0.2-unified-dmr-switch-uninstall"
INI="/opt/MMDVM_Bridge/MMDVM_Bridge.ini"
ANALOG_INI="/opt/Analog_Bridge/Analog_Bridge.ini"
VAR="/var/lib/dvswitch/dvs/var.txt"
TARGET="/usr/share/dvswitch/index.php"
MODE_HELPER="/usr/local/sbin/dvswitch-mode-buttons"
DMR_HELPER="/usr/local/sbin/dvswitch-dmr-network"
TARGET_HELPER="/usr/local/sbin/dvswitch-mode-targets"
ENDPOINT="/usr/share/dvswitch/dvswitch-mode-buttons.php"
SUDOERS="/etc/sudoers.d/dvswitch-mode-buttons"
PRESET_DIR="/etc/dvswitch-mode-buttons/dmr-presets"
LEGACY_PRESET_DIR="/etc/dvswitch-mode-buttons"

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "run with sudo"
[[ -f "$INI" ]] || die "missing $INI"
[[ -f "$TARGET" ]] || die "missing $TARGET"
[[ -f ./dvswitch-mode-buttons ]] || die 'missing unified mode helper source'
[[ -f ./dvswitch-mode-targets ]] || die 'missing target-state helper source'
[[ -f ./install-mode-target-persistence.sh ]] || die 'missing target-persistence installer'
[[ -f ./install-standalone-dmr-master-card.sh ]] || die 'missing standalone DMR-card installer'
grep -q '^switch_dmr_network(){' ./dvswitch-mode-buttons || die 'unified DMR switch function is missing'
bash -n ./dvswitch-mode-buttons ./dvswitch-mode-targets ./install-mode-target-persistence.sh ./install-standalone-dmr-master-card.sh || die 'installer source syntax validation failed'

BACKUP_DIR=/var/backups/dvswitch-mode-buttons
backup(){
  install -d -m 700 -o root -g root "$BACKUP_DIR"
  local source=$1
  [[ -e "$source" ]] || return 0
  cp -a "$source" "$BACKUP_DIR/$(basename "$source").$(date +%Y%m%d-%H%M%S)"
}

uninstall(){
  install -d -m 700 -o root -g root "$BACKUP_DIR"
  # Capture the last pre-uninstall rollback copies before backing up current files.
  latest_status=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'status.php.*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | sed -n '1s/^[^ ]* //p')
  latest_bridge=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'dvswitch.sh.*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | sed -n '1s/^[^ ]* //p')
  latest_dmr_helper=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'dvswitch-dmr-network.*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | sed -n '1s/^[^ ]* //p')
  backup "$TARGET"
  backup "$ENDPOINT"
  backup "$SUDOERS"
  backup /usr/share/dvswitch/include/status.php
  backup /opt/MMDVM_Bridge/dvswitch.sh
  backup "$DMR_HELPER"
  python3 - "$TARGET" <<'PY'
import os, sys, tempfile
path=sys.argv[1]
text=open(path, encoding='utf-8').read()
marker='<!-- DVSwitch-Mode-Buttons 1.0.0-test8 -->'
if marker in text:
    start=text.index(marker)
    end=text.lower().find('</script>', start)
    if end < 0: raise SystemExit('ERROR: mode-button script end anchor not found')
    end += len('</script>')
    text=text[:start]+text[end:]
    fd,tmp=tempfile.mkstemp(dir=os.path.dirname(path), text=True)
    with os.fdopen(fd,'w',encoding='utf-8',newline='') as f: f.write(text)
    st=os.stat(path); os.chown(tmp,st.st_uid,st.st_gid); os.chmod(tmp,st.st_mode & 0o7777); os.replace(tmp,path)
PY
  rm -f "$MODE_HELPER" "$DMR_HELPER" "$TARGET_HELPER" "$ENDPOINT" "$SUDOERS" "$DMR_HELPER".tmp.*
  rm -rf "$PRESET_DIR" /var/lib/dvswitch-mode-buttons
  [[ -z "$latest_status" ]] || install -o root -g root -m 644 "$latest_status" /usr/share/dvswitch/include/status.php
  [[ -z "$latest_bridge" ]] || install -o root -g root -m 755 "$latest_bridge" /opt/MMDVM_Bridge/dvswitch.sh
  # Restore an older standalone helper when one was present before consolidation.
  [[ -z "$latest_dmr_helper" ]] || cp -a "$latest_dmr_helper" "$DMR_HELPER"
  php -l /usr/share/dvswitch/include/status.php >/dev/null || die 'status.php validation failed after uninstall'
  systemctl restart apache2 || die 'Apache restart failed after uninstall'
  echo 'PASS: DVSwitch Mode Buttons removed; backups saved under /var/backups/dvswitch-mode-buttons.'
}

if [[ ${1:-} == "--uninstall" ]]; then
  uninstall
  exit 0
fi

if [[ ${1:-} == "" ]]; then
  echo 'DVSwitch Mode Buttons manager'
  echo '1) Install / upgrade'
  echo '2) Uninstall'
  echo '3) Exit'
  read -r -p 'Select an option: ' choice
  case "$choice" in
    1) set -- --install ;;
    2) uninstall; exit 0 ;;
    3) exit 0 ;;
    *) die 'invalid selection' ;;
  esac
fi

install_dashboard_components(){
  install -d -o root -g root -m 755 "$(dirname "$ENDPOINT")" /etc/sudoers.d
  install -o root -g root -m 644 /dev/stdin "$ENDPOINT" <<'PHP'
<?php
declare(strict_types=1);
$allowed = array('BM', 'TGIF', 'STFU', 'YSF', 'P25', 'NXDN', 'DSTAR');
if (isset($_GET['status'])) {
    $mode = '';
    $files = glob('/tmp/ABInfo_*.json');
    if (is_array($files) && count($files) > 0) {
        usort($files, static function ($a, $b) { return filemtime($b) <=> filemtime($a); });
        $data = json_decode((string)file_get_contents($files[0]), true);
        if (is_array($data)) foreach (array($data['tlv']['ambe_mode'] ?? '', $data['ambe_mode'] ?? '') as $value) {
            $value = strtoupper(trim((string)$value));
            if ($value === 'YSFN' || $value === 'YSFW') $value = 'YSF';
            if ($value !== '') { $mode = $value; break; }
        }
    }
    $address = '';
    $ini = '/opt/MMDVM_Bridge/MMDVM_Bridge.ini';
    if (is_readable($ini)) {
        $inNetwork = false;
        foreach (file($ini, FILE_IGNORE_NEW_LINES) ?: array() as $line) {
            if (trim($line) === '[DMR Network]') { $inNetwork = true; continue; }
            if ($inNetwork && preg_match('/^\s*\[/', $line)) break;
            if ($inNetwork && preg_match('/^\s*Address\s*=\s*(\S+)/i', $line, $match)) { $address = $match[1]; break; }
        }
    }
    $network = (stripos($address, 'tgif') !== false) ? 'TGIF' : ((stripos($address, 'brandmeister') !== false || stripos($address, 'repeater.net') !== false) ? 'BM' : '');
    header('Content-Type: application/json'); echo json_encode(array('ok' => $mode !== '', 'mode' => $mode, 'network' => $network)); exit;
}
$mode = strtoupper(trim((string)($_GET['mode'] ?? '')));
if (!in_array($mode, $allowed, true)) { http_response_code(400); header('Content-Type: application/json'); echo json_encode(array('ok' => false, 'error' => 'Unsupported mode')); exit; }
$output = array(); $status = 0;
exec('/usr/bin/sudo /usr/local/sbin/dvswitch-mode-buttons '.escapeshellarg($mode).' 2>&1', $output, $status);
header('Content-Type: application/json'); echo json_encode(array('ok' => $status === 0, 'mode' => $mode, 'output' => implode("\n", $output), 'status' => $status));
?>
PHP
  install -o root -g root -m 440 /dev/stdin "$SUDOERS" <<'SUDO'
www-data ALL=(root) NOPASSWD: /usr/local/sbin/dvswitch-mode-buttons BM
www-data ALL=(root) NOPASSWD: /usr/local/sbin/dvswitch-mode-buttons TGIF
www-data ALL=(root) NOPASSWD: /usr/local/sbin/dvswitch-mode-buttons STFU
www-data ALL=(root) NOPASSWD: /usr/local/sbin/dvswitch-mode-buttons YSF
www-data ALL=(root) NOPASSWD: /usr/local/sbin/dvswitch-mode-buttons P25
www-data ALL=(root) NOPASSWD: /usr/local/sbin/dvswitch-mode-buttons NXDN
www-data ALL=(root) NOPASSWD: /usr/local/sbin/dvswitch-mode-buttons DSTAR
SUDO
  visudo -cf "$SUDOERS" >/dev/null || die 'sudoers validation failed'
  php -l "$ENDPOINT" >/dev/null || die 'endpoint PHP validation failed'
  python3 - "$TARGET" <<'PY'
import os, re, shutil, sys, tempfile
path=sys.argv[1]; text=open(path, encoding='utf-8').read()
marker='<!-- DVSwitch-Mode-Buttons 1.0.0-test8 -->'
if marker in text:
    start=text.index(marker)
    end=text.lower().find('</script>', start)
    if end < 0: raise SystemExit('ERROR: existing mode-button script end anchor not found')
    end += len('</script>')
    text=text[:start]+text[end:]
if marker not in text:
    block='''<!-- DVSwitch-Mode-Buttons 1.0.0-test8 -->
<div id="dvs-mode-buttons" aria-label="Select Mode"><div class="dvs-mode-buttons-title">Select Mode</div>
<button type="button" class="button link" data-mode="BM">BM</button><button type="button" class="button link" data-mode="TGIF">TGIF</button><button type="button" class="button link" data-mode="STFU">STFU</button><button type="button" class="button link" data-mode="YSF">YSF</button><button type="button" class="button link" data-mode="P25">P25</button><button type="button" class="button link" data-mode="NXDN">NXDN</button><button type="button" class="button link" data-mode="DSTAR">D-Star</button></div>
<style>#dvs-mode-buttons{text-align:center;margin:4px auto 8px}#dvs-mode-buttons .dvs-mode-buttons-title{font-weight:bold;margin-bottom:2px}#dvs-mode-buttons button{min-width:72px;height:32px;padding:4px 10px}#dvs-mode-buttons button.selected{background-color:#008000}#dvs-mode-buttons button:disabled{opacity:.65}</style>
<script>(function(){const box=document.getElementById('dvs-mode-buttons'),buttons=[...box.querySelectorAll('button')];let syncAttempts=0;function select(mode,network){buttons.forEach(b=>b.classList.toggle('selected',b.dataset.mode===(mode==='DMR'?(network||''):mode)))}async function refresh(){try{const r=await fetch('/dvswitch/dvswitch-mode-buttons.php?status=1',{cache:'no-store'}),j=await r.json();if(j.ok)select(j.mode,j.network)}catch(e){}if(syncAttempts++<4)setTimeout(refresh,1500)}buttons.forEach(b=>b.addEventListener('click',async()=>{buttons.forEach(x=>x.disabled=true);try{const r=await fetch('/dvswitch/dvswitch-mode-buttons.php?mode='+encodeURIComponent(b.dataset.mode)),j=await r.json();if(!j.ok)throw new Error(j.output||j.error||'switch failed');select(j.mode,j.network)}catch(e){alert('Mode switch failed: '+e.message)}finally{buttons.forEach(x=>x.disabled=false)}}));refresh()})();</script>'''
    anchor=re.search(r'<div style="margin-top:8px;">', text, re.I)
    if not anchor: raise SystemExit('ERROR: RX Monitor anchor not found')
    text=text[:anchor.start()]+block+'\n'+text[anchor.start():]
    st=os.stat(path); fd,tmp=tempfile.mkstemp(dir=os.path.dirname(path))
    with os.fdopen(fd,'w',encoding='utf-8',newline='') as f: f.write(text)
    os.chown(tmp,st.st_uid,st.st_gid); os.chmod(tmp,st.st_mode & 0o7777); os.replace(tmp,path)
PY
  grep -qF '<!-- DVSwitch-Mode-Buttons 1.0.0-test8 -->' "$TARGET" || die 'dashboard button block was not installed'
}

mode="check"
[[ ${1:-} == "--install" ]] && mode="install"
[[ ${1:-} == "--check" || ${1:-} == "--install" || ${1:-} == "" ]] || die "usage: $0 [--check|--install]"

network="$(awk '
  /^\[DMR Network\]/{insec=1;next} /^\[/{insec=0}
  insec && /^[[:space:]]*Address[[:space:]]*=/{sub(/^[^=]*=/,""); gsub(/[[:space:]]/,""); print; exit}
' "$INI")"
case "$network" in
  *brandmeister*|*repeater.net|*3102*|*3104*) default_net=BM;;
  *tgif*) default_net=TGIF;;
  *) default_net=UNKNOWN;;
esac

getvar(){ awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/,""); print; exit}' "$VAR"; }

if [[ $mode == check ]]; then
  echo "DVSwitch Mode Buttons $VERSION"
  echo "MMDVM_Bridge.ini: $INI"
  echo "Current DMR network: $default_net ($network)"
  [[ -f "$VAR" ]] && echo "DVSwitch var.txt: found" || echo "DVSwitch var.txt: not found"
  echo "PASS: installer prerequisites checked; no files changed."
  echo "BM address: $(getvar bm_address)"
  echo "TGIF address: $(getvar tgif_address)"
  exit 0
fi

[[ -f "$VAR" ]] || die "missing $VAR"
[[ -f "$ANALOG_INI" ]] || die "missing $ANALOG_INI"
install -d -m 700 -o root -g root "$PRESET_DIR"
for preset in MMDVM_Bridge.BM.ini MMDVM_Bridge.TGIF.ini Analog_Bridge.BM.ini Analog_Bridge.TGIF.ini; do
  if [[ -f "$LEGACY_PRESET_DIR/$preset" && ! -f "$PRESET_DIR/$preset" ]]; then
    cp -p "$LEGACY_PRESET_DIR/$preset" "$PRESET_DIR/$preset"
  fi
done

bm_address="$(getvar bm_address)"; bm_port="$(getvar bm_port)"; bm_password="$(getvar bm_password)"
tgif_address="$(getvar tgif_address)"; tgif_port="$(getvar tgif_port)"; tgif_password="$(getvar tgif_password)"
[[ $default_net == BM || $default_net == TGIF ]] || die "current DMR address is not recognized as BM or TGIF"
cp -p "$INI" "$PRESET_DIR/MMDVM_Bridge.$default_net.ini"
alternate_net=TGIF; [[ $default_net == TGIF ]] && alternate_net=BM
current_tg="$(sed -nE '/^\[AMBE_AUDIO\][[:space:]]*$/,/^\[/ s/^[[:space:]]*txTg[[:space:]]*=[[:space:]]*([^;#[:space:]]+).*$/\1/ip' "$ANALOG_INI")"
[[ -n "$current_tg" ]] || die "current Analog_Bridge txTg is empty"
read -r -p "$alternate_net Analog_Bridge txTg for boot: " alternate_tg
[[ "$alternate_tg" =~ ^[0-9]+$ ]] || die 'Analog_Bridge txTg must be numeric'
if [[ $alternate_net == BM ]]; then
  [[ -n "$bm_address" ]] || read -r -p "BrandMeister address: " bm_address
  [[ -n "$bm_port" ]] || read -r -p "BrandMeister port: " bm_port
  [[ -n "$bm_password" ]] || { read -r -s -p "BrandMeister password: " bm_password; echo; }
else
  [[ -n "$tgif_address" ]] || read -r -p "TGIF address: " tgif_address
  [[ -n "$tgif_port" ]] || read -r -p "TGIF port: " tgif_port
  [[ -n "$tgif_password" ]] || { read -r -s -p "TGIF password: " tgif_password; echo; }
fi

[[ -n "$bm_address" && -n "$bm_port" && -n "$bm_password" ]] && bm_ok=1 || bm_ok=0
[[ -n "$tgif_address" && -n "$tgif_port" && -n "$tgif_password" ]] && tgif_ok=1 || tgif_ok=0
[[ $alternate_net == BM && $bm_ok != 1 ]] && echo "BM preset not enabled: required BM data was not provided."
[[ $alternate_net == TGIF && $tgif_ok != 1 ]] && echo "TGIF preset not enabled: required TGIF data was not provided."

export INI ANALOG_INI PRESET_DIR default_net alternate_net current_tg alternate_tg bm_address bm_port bm_password tgif_address tgif_port tgif_password bm_ok tgif_ok
python3 - <<'PY'
import os, re, shutil, tempfile
ini=os.environ['INI']; analog=os.environ['ANALOG_INI']; outdir=os.environ['PRESET_DIR']
text=open(ini, encoding='utf-8').read()
if not re.search(r'(?m)^\[DMR Network\]\s*$', text): raise SystemExit('missing [DMR Network] section')
def make(name, address, port, password):
    lines=text.splitlines(True); start=next(i for i,x in enumerate(lines) if re.match(r'^\[DMR Network\]\s*$',x)); end=next((i for i in range(start+1,len(lines)) if re.match(r'^\[.*\]\s*$',lines[i])),len(lines))
    replacement={'address':address,'port':port,'password':password}
    for i in range(start+1,end):
        m=re.match(r'^(Address|Port|Password)([ \t]*=[ \t]*)[^\r\n]*(\r?\n)?$',lines[i],re.I)
        if m:
            key=m.group(1).lower(); lines[i]=m.group(1)+m.group(2)+replacement[key]+(m.group(3) or '')
    data=''.join(lines)
    fd,tmp=tempfile.mkstemp(dir=outdir); os.close(fd); open(tmp,'w',encoding='utf-8',newline='').write(data); shutil.copystat(ini,tmp); os.chown(tmp,os.stat(ini).st_uid,os.stat(ini).st_gid); os.chmod(tmp,os.stat(ini).st_mode & 0o7777); os.replace(tmp,os.path.join(outdir,'MMDVM_Bridge.'+name+'.ini'))
if os.environ['alternate_net']=='BM' and os.environ['bm_ok']=='1': make('BM',os.environ['bm_address'],os.environ['bm_port'],os.environ['bm_password'])
if os.environ['alternate_net']=='TGIF' and os.environ['tgif_ok']=='1': make('TGIF',os.environ['tgif_address'],os.environ['tgif_port'],os.environ['tgif_password'])

analog_text=open(analog, encoding='utf-8', newline='').read()
section=re.search(r'(?ms)^\[AMBE_AUDIO\]\s*\n(.*?)(?=^\[|\Z)', analog_text)
line=re.compile(r'^(\s*txTg\s*=\s*)([^;#\r\n]+)(.*)$', re.I|re.M)
if not section or len(line.findall(section.group(1))) != 1: raise SystemExit('expected exactly one txTg in [AMBE_AUDIO]')
def analog_preset(name, value):
    def replace_tx_tg(match):
        prefix=match.group(1)
        suffix=match.group(3)
        padding=max(1, 40-len(prefix)-len(value))
        return prefix+value+(' '*padding)+suffix
    body=line.sub(replace_tx_tg, section.group(1), count=1)
    data=analog_text[:section.start(1)]+body+analog_text[section.end(1):]
    fd,tmp=tempfile.mkstemp(dir=outdir); os.close(fd)
    with open(tmp,'w',encoding='utf-8',newline='') as f: f.write(data)
    shutil.copystat(analog,tmp); st=os.stat(analog); os.chown(tmp,st.st_uid,st.st_gid); os.replace(tmp,os.path.join(outdir,'Analog_Bridge.'+name+'.ini'))
analog_preset(os.environ['default_net'], os.environ['current_tg'])
analog_preset(os.environ['alternate_net'], os.environ['alternate_tg'])
PY
chmod 700 "$PRESET_DIR"; chown -R root:root "$PRESET_DIR"
echo "PASS: created available BM/TGIF presets in $PRESET_DIR."

install_dashboard_components

./install-mode-target-persistence.sh
./install-standalone-dmr-master-card.sh
python3 - <<'PY'
from pathlib import Path
import os, tempfile

path = Path('/usr/share/dvswitch/include/status.php')
text = path.read_text(encoding='utf-8')
text = text.replace('// DVSwitch-Mode-Buttons: standalone DMR Master display v1', '// DVSwitch-Mode-Buttons: standalone DMR Master display v5', 1)
saved = r'''function dvsButtonsDmrSavedCardMode() {
        $file = '/var/lib/dvswitch-mode-buttons/last-dmr-card-mode';
        if (!is_readable($file)) { return ''; }
        $mode = strtoupper(trim((string)file_get_contents($file)));
        return in_array($mode, array('BM', 'TGIF', 'STFU'), true) ? $mode : '';
}

function dvsButtonsDmrSavedNetwork() {
        $file = '/var/lib/dvswitch-mode-buttons/last-dmr-network';
        if (!is_readable($file)) { return ''; }
        $network = strtoupper(trim((string)file_get_contents($file)));
        return in_array($network, array('BM', 'TGIF'), true) ? $network : '';
}

'''
anchor='function dvsButtonsDmrName('
if 'function dvsButtonsDmrSavedCardMode(' not in text:
    text=text.replace(anchor, saved+anchor, 1)
old_heading='''function dvsButtonsDmrMasterHeading($master, $abinfo) {
        $mode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        if ($mode === 'STFU') { return 'DMR STFU Master'; }
        return 'DMR '.dvsButtonsDmrNetwork($master).' Master';
}'''
new_heading='''function dvsButtonsDmrMasterHeading($master, $abinfo) {
        $liveMode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        if ($liveMode === 'STFU') { return 'DMR STFU Master'; }
        if ($liveMode === 'DMR') { return 'DMR '.dvsButtonsDmrNetwork($master).' Master'; }
        $saved = dvsButtonsDmrSavedCardMode();
        if ($saved === 'STFU') { return 'DMR STFU Master'; }
        if ($saved === 'BM' || $saved === 'TGIF') { return 'DMR '.$saved.' Master'; }
        return 'DMR '.dvsButtonsDmrNetwork($master).' Master';
}'''
old_v5_heading='''function dvsButtonsDmrMasterHeading($master, $abinfo) {
        $liveMode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        $saved = dvsButtonsDmrSavedCardMode();
        if ($liveMode === 'STFU' || $saved === 'STFU') { return 'DMR STFU Master'; }
        if ($saved === 'BM' || $saved === 'TGIF') { return 'DMR '.$saved.' Master'; }
        return 'DMR '.dvsButtonsDmrNetwork($master).' Master';
}'''
text=text.replace(old_heading,new_heading,1)
text=text.replace(old_v5_heading,new_heading,1)
old_display='''function dvsButtonsDmrMasterDisplay($master, $abinfo) {
        $mode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        $network = ($mode === 'STFU') ? 'BM' : dvsButtonsDmrNetwork($master);
        $talkgroup = dvsButtonsDmrTalkgroup($abinfo);'''
new_display='''function dvsButtonsDmrMasterDisplay($master, $abinfo) {
        $liveMode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
        if ($liveMode === 'DMR') {
                $network = dvsButtonsDmrNetwork($master);
        } elseif ($liveMode === 'STFU') {
                $network = 'BM';
        } else {
                $saved = dvsButtonsDmrSavedCardMode();
                $network = ($saved === 'STFU') ? 'BM' : dvsButtonsDmrSavedNetwork();
                if ($network === '') { $network = dvsButtonsDmrNetwork($master); }
        }
        $talkgroup = dvsButtonsDmrTalkgroup($abinfo);'''
old_v5_display='''function dvsButtonsDmrMasterDisplay($master, $abinfo) {
        $saved = dvsButtonsDmrSavedCardMode();
        $network = ($saved === 'STFU') ? 'BM' : dvsButtonsDmrSavedNetwork();
        if ($network === '') { $network = dvsButtonsDmrNetwork($master); }
        $talkgroup = dvsButtonsDmrTalkgroup($abinfo);'''
text=text.replace(old_display,new_display,1)
text=text.replace(old_v5_display,new_display,1)
plain_master = "return 'Room<br>'.htmlspecialchars((string)$master, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');"
plain_display = "return 'Room<br>'.htmlspecialchars($display, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');"
formatted_master = "return '<span style=\"color:#000000;font-weight:normal;\">Room</span><br/><span style=\"color:#b5651d;font-weight:bold;\">'.htmlspecialchars((string)$master, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8').'</span>';"
formatted_display = "return '<span style=\"color:#000000;font-weight:normal;\">Room</span><br/><span style=\"color:#b5651d;font-weight:bold;\">'.htmlspecialchars($display, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8').'</span>';"
if text.count(plain_master) == 1 and text.count(plain_display) == 1:
    text = text.replace(plain_master, formatted_master, 1)
    text = text.replace(plain_display, formatted_display, 1)
elif text.count(formatted_master) == 1 and text.count(formatted_display) == 1:
    pass
else:
    raise SystemExit('ERROR: DMR Room-label formatting is incomplete or ambiguous')
if 'standalone DMR Master display v5' not in text or 'dvsButtonsDmrSavedCardMode' not in text:
    raise SystemExit('ERROR: state-aware DMR card upgrade was not applied')
stat=path.stat(); fd,tmp=tempfile.mkstemp(dir=path.parent)
with os.fdopen(fd,'w',encoding='utf-8',newline='') as f: f.write(text)
os.chown(tmp,stat.st_uid,stat.st_gid); os.chmod(tmp,stat.st_mode & 0o7777); os.replace(tmp,path)
PY
php -l /usr/share/dvswitch/include/status.php >/dev/null || die 'state-aware DMR card upgrade failed'
install -d /var/lib/dvswitch-mode-buttons
chown root:root /var/lib/dvswitch-mode-buttons
chmod 755 /var/lib/dvswitch-mode-buttons
for state_file in current-mode last-dmr-card-mode last-dmr-network; do
  if [[ -e "/var/lib/dvswitch-mode-buttons/$state_file" ]]; then
    chown root:root "/var/lib/dvswitch-mode-buttons/$state_file"
    chmod 644 "/var/lib/dvswitch-mode-buttons/$state_file"
  fi
done
php -l /usr/share/dvswitch/include/status.php
systemctl restart apache2
echo "PASS: mode helpers, target persistence, standalone DMR card, and permissions installed."
echo '!!!!!!!!   NOTICE !!!!!!!!'
echo 'NOTICE: If the DVSwitch dashboard was already open, refresh that browser tab (press F5) to display the new buttons.'
