#!/usr/bin/env bash
set -u

TARGET="/usr/share/dvswitch/include/status.php"
MARKER="// DVSwitch-Mode-Buttons: STFU Net card v1"
[[ $EUID -eq 0 ]] || { echo "ERROR: run with sudo" >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "ERROR: missing $TARGET" >&2; exit 1; }

python3 - "$TARGET" <<'PY'
import os, shutil, sys
from pathlib import Path
path=Path(sys.argv[1]); text=path.read_text()
marker='// DVSwitch-Mode-Buttons: STFU Net card v1'
if text.count(marker) == 1:
    print('ALREADY INSTALLED: STFU Net card is present.'); raise SystemExit(0)
if text.count(marker) != 0:
    raise SystemExit('ERROR: ambiguous STFU card marker')
anchor='''echo "</table>\\n";
}
$testMMDVModeYSF = getConfigItem("System Fusion Network", "Enable", $mmdvmconfigs);'''
if text.count(anchor) != 1:
    raise SystemExit(f'ERROR: expected one DMR-to-YSF insertion point, found {text.count(anchor)}')
card='''echo "</table>\\n";
}
// DVSwitch-Mode-Buttons: STFU Net card v1
echo "<br />\\n";
echo "<table>\\n";
echo "<tr><th colspan=\\"2\\">STFU Net</th></tr>\\n";
echo "<tr><td colspan=\\"2\\" style=\\"background: #ffffed;\\"><span style=\\"color:#b0b0b0;font-weight: bold\\">Not Linked</span></td></tr>\\n";
echo "</table>\\n";
$testMMDVModeYSF = getConfigItem("System Fusion Network", "Enable", $mmdvmconfigs);'''
updated=text.replace(anchor,card,1)
tmp=path.with_name(path.name+'.tmp-stfu-card'); tmp.write_text(updated); shutil.copystat(path,tmp); os.chown(tmp,os.stat(path).st_uid,os.stat(path).st_gid); os.replace(tmp,path)
print('PASS: STFU Net card installed above YSF Net.')
PY
