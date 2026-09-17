#!/usr/bin/env bash
set -Eeuo pipefail

TARGET=/usr/share/dvswitch/include/status.php
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo' >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "ERROR: missing $TARGET" >&2; exit 1; }

python3 - "$TARGET" <<'PY'
import shutil, sys
from pathlib import Path

path = Path(sys.argv[1]); text = path.read_text(encoding='utf-8')
old_marker = '// DVSwitch-Mode-Buttons: STFU Net card v8'
new_marker = '// DVSwitch-Mode-Buttons: STFU Net card v9'
if text.count(new_marker) == 1:
    print('ALREADY INSTALLED: STFU Net card v9 is present.')
    raise SystemExit(0)
if text.count(old_marker) != 1:
    raise SystemExit('ERROR: expected exactly one STFU card v8')

start = text.index(old_marker)
end = text.index('$testMMDVModeYSF = getConfigItem("System Fusion Network", "Enable", $mmdvmconfigs);', start)
old = text[start:end]
new = old.replace(old_marker, new_marker, 1)
brand_row = '<span style=\\"color:#b5651d;font-weight:bold;\\">BrandMeister</span></td></tr><tr><td colspan=\\"2\\" style=\\"background:#ffffed;\\">'
new = new.replace(brand_row, '')
if new == old or 'BrandMeister' in new or '(TG ' in new:
    raise SystemExit('ERROR: STFU v9 display replacement failed')
backup = path.with_name(path.name + '.before-stfu-card-v9')
if backup.exists(): raise SystemExit(f'ERROR: backup already exists: {backup}')
shutil.copy2(path, backup)
path.write_text(text[:start] + new + text[end:], encoding='utf-8')
print(f'PASS: STFU card v9 installed. Backup: {backup}')
PY

php -l "$TARGET" >/dev/null || { echo 'ERROR: PHP validation failed; restore the v9 backup.' >&2; exit 1; }
