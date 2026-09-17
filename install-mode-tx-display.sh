#!/usr/bin/env bash
set -Eeuo pipefail

TARGET=/usr/share/dvswitch/include/status.php
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo' >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "ERROR: missing $TARGET" >&2; exit 1; }

python3 - "$TARGET" <<'PY'
import os, shutil, sys
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
old='''    // DVSwitch-Mods: D-Star Tx TG/Ref display v1
    $txValue = $abinfo['digital']['tg'];
    if ($abinfo['tlv']['ambe_mode'] == "DSTAR") {
        $txValue = preg_replace('/^(Linked to|Linking to)\\s+/i', '', trim(strip_tags(str_replace("<br />", " ", getDSTARLinks()))));
        $txValue = preg_replace('/\\s*\\(.*\\)\\s*$/', '', $txValue);
    }
'''
new='''    // DVSwitch-Mode-Buttons: active mode Tx TG/Ref display v1
    $txValue = $abinfo['digital']['tg'];
    $activeMode = strtoupper((string)($abinfo['tlv']['ambe_mode'] ?? ''));
    if ($activeMode === "YSFN" || $activeMode === "YSFW") {
        $txValue = getActualLink($reverseLogLinesYSFGateway, "YSF");
    } elseif ($activeMode === "P25") {
        $txValue = getActualLink($logLinesP25Gateway, "P25");
    } elseif ($activeMode === "NXDN") {
        $txValue = getActualLink($logLinesNXDNGateway, "NXDN");
    } elseif ($activeMode === "DSTAR") {
        $txValue = preg_replace('/^(Linked to|Linking to)\\s+/i', '', trim(strip_tags(str_replace("<br />", " ", getDSTARLinks()))));
        $txValue = preg_replace('/\\s*\\(.*\\)\\s*$/', '', $txValue);
    }
'''
if s.count(old) != 1: raise SystemExit(f'ERROR: expected exactly one Tx display block; found {s.count(old)}')
backup=p.with_name(p.name+'.before-mode-tx-display')
if backup.exists(): raise SystemExit(f'ERROR: backup already exists: {backup}')
shutil.copy2(p,backup)
tmp=p.with_name(p.name+'.tmp-mode-tx-display'); tmp.write_text(s.replace(old,new,1),encoding='utf-8',newline='')
shutil.copystat(p,tmp); os.chown(tmp,os.stat(p).st_uid,os.stat(p).st_gid); os.replace(tmp,p)
print(f'PASS: active mode Tx TG/Ref display installed. Backup: {backup}')
PY
php -l "$TARGET"
