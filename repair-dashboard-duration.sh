#!/usr/bin/env bash
set -Eeuo pipefail

TARGET=/usr/share/dvswitch/include/functions.php
MARKER='// DVSwitch-Mods: dashboard duration type repair v1'
OLD='''    if ($listElem[6] != null) { //if terminated, hangtime counts after end of transmission
        $timestamp->add(new DateInterval('PT' . ceil($listElem[6]) . 'S'));'''
NEW='''    if ($listElem[6] != null) { //if terminated, hangtime counts after end of transmission
        // Text durations such as GPS, DMR Data, and --- are valid activity states.
        if (!is_numeric($listElem[6])) { return $mode; }
        $timestamp->add(new DateInterval('PT' . ceil((float)$listElem[6]) . 'S'));'''

die() { echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "run with sudo"
[[ -f "$TARGET" ]] || die "missing $TARGET"

python3 - "$TARGET" "${1:---check}" <<'PY'
import shutil, sys
from pathlib import Path

path = Path(sys.argv[1])
action = sys.argv[2] if len(sys.argv) > 2 else "--check"
text = path.read_text(encoding="utf-8")
marker = "// DVSwitch-Mods: dashboard duration type repair v1"
old = """    if ($listElem[6] != null) { //if terminated, hangtime counts after end of transmission
        $timestamp->add(new DateInterval('PT' . ceil($listElem[6]) . 'S'));"""
new = """    if ($listElem[6] != null) { //if terminated, hangtime counts after end of transmission
        // Text durations such as GPS, DMR Data, and --- are valid activity states.
        if (!is_numeric($listElem[6])) { return $mode; }
        $timestamp->add(new DateInterval('PT' . ceil((float)$listElem[6]) . 'S'));"""

if text.count(marker) > 1:
    raise SystemExit("ERROR: ambiguous dashboard duration repair")
if marker in text:
    print("ALREADY REPAIRED: dashboard duration handling is installed.")
    raise SystemExit(0)
if text.count(old) != 1:
    raise SystemExit("ERROR: expected exactly one stock duration target")
if action == "--check":
    print("READY: dashboard duration repair available; no files changed.")
    raise SystemExit(0)
if action != "--install":
    raise SystemExit("ERROR: usage: repair-dashboard-duration.sh [--check|--install]")

backup = path.with_name(path.name + ".before-dashboard-duration-repair")
if backup.exists():
    raise SystemExit(f"ERROR: backup already exists: {backup}")
shutil.copy2(path, backup)
path.write_text(text.replace(old, marker + "\n" + new, 1), encoding="utf-8")
print(f"PASS: dashboard duration repair installed. Backup: {backup}")
PY

php -l "$TARGET" >/dev/null || { echo "ERROR: PHP validation failed; restoring backup." >&2; cp -p "$TARGET.before-dashboard-duration-repair" "$TARGET"; exit 1; }
