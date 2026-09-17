#!/usr/bin/env bash
set -u

TARGET="/usr/share/dvswitch/include/status.php"
[[ $EUID -eq 0 ]] || { echo "ERROR: run with sudo" >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "ERROR: missing $TARGET" >&2; exit 1; }

python3 - "$TARGET" <<'PY'
import os, shutil, sys
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text()
old_marker='// DVSwitch-Mode-Buttons: STFU Net card v2'
if s.count(old_marker) != 1: raise SystemExit('ERROR: expected exactly one STFU card v2')
a=s.find(old_marker); b=s.find('echo "</table>\\n";',a)
if b < 0: raise SystemExit('ERROR: STFU card end not found')
b += len('echo "</table>\\n";')
new='''// DVSwitch-Mode-Buttons: STFU Net card v3
$stfuConfig = array();
if (is_readable('/opt/MMDVM_Bridge/DVSwitch.ini')) { $stfuConfig = parse_ini_file('/opt/MMDVM_Bridge/DVSwitch.ini', true); }
$stfuStartTG = isset($stfuConfig['STFU']['StartTG']) ? trim((string)$stfuConfig['STFU']['StartTG']) : '';
$stfuMode = isset($abinfo['tlv']['ambe_mode']) ? strtoupper(trim((string)$abinfo['tlv']['ambe_mode'])) : '';
$stfuTG = ($stfuMode === 'STFU') ? $stfuStartTG : '';
$stfuName = '';
if ($stfuTG !== '' && is_readable('/var/lib/mmdvm/TGList_BM.txt')) {
    foreach (file('/var/lib/mmdvm/TGList_BM.txt', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: array() as $stfuLine) {
        $stfuFields = explode(';', $stfuLine, 4);
        if (count($stfuFields) >= 3 && trim($stfuFields[0]) === $stfuTG && trim($stfuFields[1]) === '0') { $stfuName = trim($stfuFields[2]); break; }
    }
}
echo "<br />\\n";
echo "<table>\\n";
echo "<tr><th colspan=\\"2\\">STFU Net</th></tr>\\n";
if ($stfuTG !== '') {
    $stfuDisplay = ($stfuName !== '') ? $stfuName.' (TG '.$stfuTG.')' : 'TG '.$stfuTG;
    echo "<tr><td colspan=\\"2\\" style=\\"background: #ffffed;\\"><span style=\\"color:#b5651d;font-weight: bold;\\">".htmlspecialchars($stfuDisplay, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')."</span></td></tr>\\n";
} else {
    echo "<tr><td colspan=\\"2\\" style=\\"background: #ffffed;\\"><span style=\\"color:#b0b0b0;font-weight: bold\\">Not Linked</span></td></tr>\\n";
}
echo "</table>\\n";'''
tmp=p.with_name(p.name+'.tmp-stfu-card'); tmp.write_text(s[:a]+new+s[b:]); shutil.copystat(p,tmp); os.chown(tmp,os.stat(p).st_uid,os.stat(p).st_gid); os.replace(tmp,p)
print('PASS: STFU card now uses StartTG only while STFU is active.')
PY
