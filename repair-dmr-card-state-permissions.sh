#!/usr/bin/env bash
set -Eeuo pipefail

STATE_DIR=/var/lib/dvswitch-mode-buttons
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo' >&2; exit 1; }
getent group www-data >/dev/null || { echo 'ERROR: group www-data does not exist' >&2; exit 1; }
[[ -d "$STATE_DIR" ]] || { echo "ERROR: missing $STATE_DIR" >&2; exit 1; }

chown root:www-data "$STATE_DIR"
chmod 750 "$STATE_DIR"
for file in current-mode last-dmr-card-mode last-dmr-network; do
    if [[ -e "$STATE_DIR/$file" ]]; then
        chown root:www-data "$STATE_DIR/$file"
        chmod 640 "$STATE_DIR/$file"
    fi
done

echo 'PASS: DMR card state is readable by Apache and remains writable only by root.'
stat -c '%A %U:%G %n' "$STATE_DIR" "$STATE_DIR"/* 2>/dev/null || true
