#!/usr/bin/env bash
set -Eeuo pipefail
TARGET=/usr/share/dvswitch/include/status.php
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo' >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "ERROR: missing $TARGET" >&2; exit 1; }
python3 - "$TARGET" <<'PY'
import os, shutil, sys
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
old="""    $txValue = $abinfo['digital']['tg'];
    if ($abinfo['tlv']['ambe_mode'] == \"DSTAR\") {
        $txValue = preg_replace('/^(Linked to|Linking to)\\s+/i', '', trim(strip_tags(str_replace("<br />", " ", getDSTARLinks()))));
        $txValue = preg_replace('/\\s*\\(.*\\)\\s*$/', '', $txValue);
    }
"""
new="""    $txValue = $abinfo['digital']['tg'];
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
"""
if s.count(old) != 1: raise SystemExit(f'ERROR: expected one Tx display block; found {s.count(old)}')
b=p.with_name(p.name+'.before-mode-tx-display-v2')
if b.exists(): raise SystemExit(f'ERROR: backup already exists: {b}')
shutil.copy2(p,b)
t=p.with_name(p.name+'.tmp-mode-tx-display-v2')
t.write_text(s.replace(old,new,1),encoding='utf-8',newline='')
shutil.copystat(p,t); os.chown(t,os.stat(p).st_uid,os.stat(p).st_gid); os.replace(t,p)
print(f'PASS: selected-mode Tx TG/Ref display installed. Backup: {b}')
PY
php -l "$TARGET"
