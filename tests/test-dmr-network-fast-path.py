#!/usr/bin/env python3
# SPDX-License-Identifier: MIT

"""Verify BM/TGIF clicks skip copies and restarts only when both INIs match."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "dvswitch-mode-buttons").read_text(encoding="utf-8")


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "etc/dvswitch-mode-buttons/dmr-presets").mkdir(parents=True)
        (root / "opt/MMDVM_Bridge").mkdir(parents=True)
        (root / "opt/Analog_Bridge").mkdir(parents=True)
        bin_dir = root / "bin"
        bin_dir.mkdir()
        log = root / "calls.log"
        mode_cmd = root / "opt/MMDVM_Bridge/dvswitch.sh"
        mode_cmd.write_text("#!/bin/sh\nprintf 'mode %s\\n' \"$*\" >> \"$CALL_LOG\"\n", encoding="utf-8")
        mode_cmd.chmod(0o755)
        systemctl = bin_dir / "systemctl"
        systemctl.write_text("#!/bin/sh\nprintf 'systemctl %s\\n' \"$*\" >> \"$CALL_LOG\"\n", encoding="utf-8")
        systemctl.chmod(0o755)

        helper = root / "dvswitch-mode-buttons"
        helper.write_text(SOURCE.replace(
            "MODE_CMD=/opt/MMDVM_Bridge/dvswitch.sh", f"MODE_CMD={mode_cmd}"
        ).replace(
            "STATE_DIR=/var/lib/dvswitch-mode-buttons", f"STATE_DIR={root}/state"
        ).replace(
            "PRESET_DIR=/etc/dvswitch-mode-buttons/dmr-presets",
            f"PRESET_DIR={root}/etc/dvswitch-mode-buttons/dmr-presets",
        ).replace(
            "INI=/opt/MMDVM_Bridge/MMDVM_Bridge.ini", f"INI={root}/opt/MMDVM_Bridge/MMDVM_Bridge.ini"
        ).replace(
            "ANALOG_INI=/opt/Analog_Bridge/Analog_Bridge.ini", f"ANALOG_INI={root}/opt/Analog_Bridge/Analog_Bridge.ini"
        ).replace(
            "DMR_HISTORY_WRITER=/usr/local/sbin/dvswitch-mods-record-dmr-network",
            f"DMR_HISTORY_WRITER={root}/missing-history-writer",
        ), encoding="utf-8")
        helper.chmod(0o755)

        env = os.environ.copy()
        env.update(PATH=f"{bin_dir}:{env['PATH']}", CALL_LOG=str(log))
        preset_dir = root / "etc/dvswitch-mode-buttons/dmr-presets"
        mmdvm = "[DMR Network]\nAddress=tgif.network\nPort=62030\nPassword=secret\n"
        analog = "[AMBE_AUDIO]\ntxTg=12345\n"
        live_mmdvm = root / "opt/MMDVM_Bridge/MMDVM_Bridge.ini"
        live_analog = root / "opt/Analog_Bridge/Analog_Bridge.ini"
        (preset_dir / "MMDVM_Bridge.TGIF.ini").write_text(mmdvm, encoding="utf-8")
        (preset_dir / "Analog_Bridge.TGIF.ini").write_text(analog, encoding="utf-8")

        # Same network and matching companion INI: mode only, no copy or restart.
        live_mmdvm.write_text(mmdvm, encoding="utf-8")
        live_analog.write_text(analog, encoding="utf-8")
        result = subprocess.run([str(helper), "TGIF"], env=env, text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
        calls = log.read_text(encoding="utf-8").splitlines()
        assert calls == ["mode mode DMR", "systemctl is-active --quiet analog_bridge mmdvm_bridge"], calls
        assert "skipped preset copies and service restart" in result.stdout

        # A differing Analog_Bridge file still takes the established full path.
        log.write_text("", encoding="utf-8")
        live_analog.write_text("[AMBE_AUDIO]\ntxTg=99999\n", encoding="utf-8")
        result = subprocess.run([str(helper), "TGIF"], env=env, text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
        calls = log.read_text(encoding="utf-8").splitlines()
        assert "systemctl restart analog_bridge mmdvm_bridge" in calls, calls
        assert live_analog.read_text(encoding="utf-8") == analog

    print("PASS: matching BM/TGIF presets skip recopy/restart; mismatches use the full switch path")


if __name__ == "__main__":
    main()
