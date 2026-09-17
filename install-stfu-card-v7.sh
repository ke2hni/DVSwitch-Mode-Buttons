#!/usr/bin/env bash
set -Eeuo pipefail

TARGET=/usr/share/dvswitch/include/status.php
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo' >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "ERROR: missing $TARGET" >&2; exit 1; }

python3 - "$TARGET" <<'PY'
import os, shutil, sys
from pathlib import Path

path = Path(sys.argv[1]); text = path.read_text(encoding='utf-8')
marker = '// DVSwitch-Mode-Buttons: STFU Net card v7'
if marker in text:
    print('ALREADY INSTALLED: STFU Net card v7 is present.')
    raise SystemExit(0)
if 'STFU Net card v' in text:
    raise SystemExit('ERROR: an older STFU card is installed; remove it before v7.')
anchor = '$testMMDVModeYSF = getConfigItem("System Fusion Network", "Enable", $mmdvmconfigs);'
if text.count(anchor) != 1:
    raise SystemExit('ERROR: expected exactly one YSF dashboard anchor')

card = r'''// DVSwitch-Mode-Buttons: STFU Net card v7
$stfuStartTG = '';
$stfuInSection = false;
$stfuConfigPath = '/opt/MMDVM_Bridge/DVSwitch.ini';
if (is_readable($stfuConfigPath)) {
    foreach (file($stfuConfigPath, FILE_IGNORE_NEW_LINES) ?: array() as $stfuConfigLine) {
        $stfuTrim = trim($stfuConfigLine);
        if (preg_match('/^\[STFU\](?:\s*;.*)?$/i', $stfuTrim)) { $stfuInSection = true; continue; }
        if ($stfuInSection && preg_match('/^\[.*\]/', $stfuTrim)) { break; }
        if ($stfuInSection && preg_match('/^StartTG\s*=\s*([0-9]+)/i', $stfuTrim, $stfuMatch)) { $stfuStartTG = $stfuMatch[1]; break; }
    }
}
$stfuName = '';
if ($stfuStartTG !== '' && is_readable('/var/lib/mmdvm/TGList_BM.txt')) {
    foreach (file('/var/lib/mmdvm/TGList_BM.txt', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: array() as $stfuListLine) {
        $stfuFields = explode(';', $stfuListLine, 4);
        if (count($stfuFields) === 4 && trim($stfuFields[0]) === $stfuStartTG && trim($stfuFields[1]) === '0') { $stfuName = trim($stfuFields[2]); break; }
    }
}
echo "<br><table><tr><th colspan=\"2\">STFU Net</th></tr><tr><td colspan=\"2\" style=\"background:#ffffed;\">";
$stfuDisplay = ($stfuStartTG !== '') ? (($stfuName !== '') ? $stfuName.' (TG '.$stfuStartTG.')' : 'TG '.$stfuStartTG) : 'Not Linked';
echo '<span style="color:#b5651d;font-weight:bold;">'.htmlspecialchars($stfuDisplay, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8').'</span></td></tr></table>';
'''
backup = path.with_name(path.name + '.before-stfu-card-v7')
if backup.exists(): raise SystemExit(f'ERROR: backup already exists: {backup}')
shutil.copy2(path, backup)
path.write_text(text.replace(anchor, card + '\n' + anchor, 1), encoding='utf-8')
print(f'PASS: STFU Net card v7 installed. Backup: {backup}')
PY
php -l "$TARGET" >/dev/null || { echo 'ERROR: PHP validation failed; restore the v7 backup.' >&2; exit 1; }
