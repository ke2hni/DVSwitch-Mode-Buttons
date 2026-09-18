#!/usr/bin/env bash
set -Eeuo pipefail
TARGET=/usr/share/dvswitch/include/status.php
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo' >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "ERROR: missing $TARGET" >&2; exit 1; }
python3 - "$TARGET" <<'PY'
import os, re, shutil, sys
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
start='    // DVSwitch-Mode-Buttons: active mode Tx TG/Ref display v1\n'
end='    echo "<table style=\\"margin-top:4px;\\">\\n";\n'
a=s.find(start); b=s.find(end,a)
if a < 0 or b < 0: raise SystemExit('ERROR: expected installed active-mode Tx display block was not found')
b += len(end)-len(end)
old=s[a:b]
new='''    // DVSwitch-Mode-Buttons: selected mode Tx TG/Ref display v2
    $txValue = $abinfo['digital']['tg'];
    $selectedMode = is_readable('/var/lib/dvswitch-mode-buttons/current-mode') ? strtoupper(trim(file_get_contents('/var/lib/dvswitch-mode-buttons/current-mode'))) : strtoupper((string)($abinfo['tlv']['ambe_mode'] ?? ''));
    if ($selectedMode === "YSF" || $selectedMode === "YSFN" || $selectedMode === "YSFW") {
        $txValue = getActualLink($reverseLogLinesYSFGateway, "YSF");
    } elseif ($selectedMode === "P25") {
        $txValue = getActualLink($logLinesP25Gateway, "P25");
    } elseif ($selectedMode === "NXDN") {
        $txValue = getActualLink($logLinesNXDNGateway, "NXDN");
    } elseif ($selectedMode === "DSTAR") {
        $txValue = preg_replace('/^(Linked to|Linking to)\\s+/i', '', trim(strip_tags(str_replace("<br />", " ", getDSTARLinks()))));
        $txValue = preg_replace('/\\s*\\(.*\\)\\s*$/', '', $txValue);
    }
'''
backup=p.with_name(p.name+'.before-mode-tx-display-v3')
if backup.exists(): raise SystemExit(f'ERROR: backup already exists: {backup}')
shutil.copy2(p,backup); t=p.with_name(p.name+'.tmp-mode-tx-display-v3'); t.write_text(s[:a]+new+s[b:],encoding='utf-8',newline=''); shutil.copystat(p,t); os.chown(t,os.stat(p).st_uid,os.stat(p).st_gid); os.replace(t,p)
print(f'PASS: selected-mode Tx TG/Ref display v2 installed. Backup: {backup}')
PY
php -l "$TARGET"
