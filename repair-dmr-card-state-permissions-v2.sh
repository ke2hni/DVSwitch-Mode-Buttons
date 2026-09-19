#!/usr/bin/env bash
set -Eeuo pipefail

STATE_DIR=/var/lib/dvswitch-mode-buttons
[[ $EUID -eq 0 ]] || { echo 'ERROR: run with sudo' >&2; exit 1; }
[[ -d "$STATE_DIR" ]] || { echo "ERROR: missing $STATE_DIR" >&2; exit 1; }

chown root:root "$STATE_DIR"
chmod 755 "$STATE_DIR"
for file in current-mode last-dmr-card-mode last-dmr-network; do
    if [[ -e "$STATE_DIR/$file" ]]; then
        chown root:root "$STATE_DIR/$file"
        chmod 644 "$STATE_DIR/$file"
    fi
done

echo 'PASS: DMR card state is readable by PHP and writable only by root.'
stat -c '%A %U:%G %n' "$STATE_DIR" "$STATE_DIR"/* 2>/dev/null || true
