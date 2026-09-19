#!/usr/bin/env bash
set -Eeuo pipefail

TARGET=/usr/share/dvswitch/index.php
MODE_HELPER=/usr/local/sbin/dvswitch-mode-buttons
DMR_HELPER=/usr/local/sbin/dvswitch-dmr-network
ENDPOINT=/usr/share/dvswitch/dvswitch-mode-buttons.php
SUDOERS=/etc/sudoers.d/dvswitch-mode-buttons
PRESET_DIR=/etc/dvswitch-mode-buttons
MODE_STATE_DIR=/var/lib/dvswitch-mode-buttons
BACKUP_ROOT=/var/backups/dvswitch-mode-buttons

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die 'run with sudo'
[[ -f "$TARGET" ]] || die "missing $TARGET"

case "${1:-}" in
  --check|--uninstall) ;;
  *) echo "Usage: sudo $0 --check|--uninstall" >&2; exit 2 ;;
esac

dashboard_count(){
  grep -Eoc '<!-- DVSwitch-Mode-Buttons 1\.0\.0-test[0-9]+ -->' "$TARGET" || true
}

dashboard_present(){
  (( $(dashboard_count) > 0 ))
}

if [[ $1 == --check ]]; then
  found=0
  for path in "$MODE_HELPER" "$DMR_HELPER" "$ENDPOINT" "$SUDOERS" "$PRESET_DIR" "$MODE_STATE_DIR"; do
    if [[ -e "$path" || -L "$path" ]]; then
      found=1
      echo "FOUND: $path"
    fi
  done
  if dashboard_present; then
    found=1
    echo "FOUND: dashboard mode-button block ($(dashboard_count))"
  fi
  if (( found == 0 )); then
    echo 'ALREADY REMOVED: DVSwitch mode buttons are not installed.'
  else
    echo 'PASS: mode-button installation detected; no files changed.'
  fi
  exit 0
fi

found=0
for path in "$MODE_HELPER" "$DMR_HELPER" "$ENDPOINT" "$SUDOERS" "$PRESET_DIR" "$MODE_STATE_DIR"; do
  if [[ -e "$path" || -L "$path" ]]; then found=1; fi
done
dashboard_present && found=1

if (( found == 0 )); then
  echo 'ALREADY REMOVED: DVSwitch mode buttons are not installed.'
  exit 0
fi

stamp=$(date +%Y%m%d-%H%M%S)
backup="$BACKUP_ROOT/uninstall-$stamp"
install -d -o root -g root -m 0700 "$backup"

cp -a -- "$TARGET" "$backup/index.php"
for path in "$MODE_HELPER" "$DMR_HELPER" "$ENDPOINT" "$SUDOERS"; do
  if [[ -e "$path" || -L "$path" ]]; then
    cp -a -- "$path" "$backup/$(basename "$path")"
  fi
done
if [[ -d "$PRESET_DIR" && ! -L "$PRESET_DIR" ]]; then
  cp -a -- "$PRESET_DIR" "$backup/"
fi
if [[ -d "$MODE_STATE_DIR" && ! -L "$MODE_STATE_DIR" ]]; then
  cp -a -- "$MODE_STATE_DIR" "$backup/"
fi

TARGET_FILE="$TARGET" python3 - <<'PY'
from pathlib import Path
import os
import re
import shutil
import stat
import tempfile

path = Path(os.environ['TARGET_FILE'])
text = path.read_text(encoding='utf-8')
pattern = re.compile(
    r'<!-- DVSwitch-Mode-Buttons 1\.0\.0-test[0-9]+ -->.*?</script>\s*',
    re.DOTALL,
)
matches = pattern.findall(text)
if len(matches) > 1:
    raise SystemExit('ERROR: multiple dashboard mode-button blocks found; no dashboard changes made')
if len(matches) == 1:
    updated = text.replace(matches[0], '', 1)
    mode = stat.S_IMODE(path.stat().st_mode)
    fd, name = tempfile.mkstemp(prefix=f'.{path.name}.', dir=str(path.parent), text=True)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='') as target:
            target.write(updated)
        shutil.copystat(path, name)
        os.chown(name, path.stat().st_uid, path.stat().st_gid)
        os.chmod(name, mode)
        os.replace(name, path)
    except Exception:
        try:
            os.unlink(name)
        except FileNotFoundError:
            pass
        raise
PY

rm -f -- "$MODE_HELPER" "$DMR_HELPER" "$ENDPOINT" "$SUDOERS"
rm -rf -- "$PRESET_DIR" "$MODE_STATE_DIR"

if dashboard_present; then
  die 'dashboard mode-button block remains after removal'
fi
for path in "$MODE_HELPER" "$DMR_HELPER" "$ENDPOINT" "$SUDOERS" "$PRESET_DIR" "$MODE_STATE_DIR"; do
  [[ ! -e "$path" && ! -L "$path" ]] || die "mode-button file remains: $path"
done

php -l "$TARGET" >/dev/null || die 'dashboard PHP validation failed after removal'
echo "PASS: DVSwitch mode buttons removed."
echo "PASS: dashboard validated and unrelated DVSwitch files were not changed."
echo "PASS: backup: $backup"
