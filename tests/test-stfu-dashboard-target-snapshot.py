#!/usr/bin/env python3
"""Check that the private STFU target is safely exposed to the dashboard."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGETS = (ROOT / "dvswitch-mode-targets").read_text(encoding="utf-8")
INSTALLER = (ROOT / "install-mode-target-persistence.sh").read_text(encoding="utf-8")

assert "if mode == 'STFU':" in TARGETS
assert "prefix='.stfu-target.'" in TARGETS
assert "os.chmod(public_tmp, 0o644)" in TARGETS
assert "os.replace(public_tmp, os.path.join(os.path.dirname(path), 'stfu-target'))" in TARGETS
assert "os.chmod(tmp,0o600)" in TARGETS, "canonical per-mode JSON must remain private"
assert '"$TARGET_HELPER" get STFU' in INSTALLER
assert '"$STATE_DIR/stfu-target"' in INSTALLER
assert 'chmod 644 "$stfu_tmp"' in INSTALLER

print("PASS: STFU target snapshot is atomically published read-only; canonical state stays private")
