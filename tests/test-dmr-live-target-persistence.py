#!/usr/bin/env python3
# SPDX-License-Identifier: MIT

"""Exercise the installer upgrade from an installed v6 DMR card."""

from __future__ import annotations

import ast
import os
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = (ROOT / "dvswitch-mode-buttons.sh").read_text()


def embedded_python() -> str:
    install_call = INSTALLER.index("\n./install-standalone-dmr-master-card.sh\n")
    start = INSTALLER.index("python3 - <<'PY'\n", install_call)
    end = INSTALLER.index("\nPY\n", start)
    code = INSTALLER[start + len("python3 - <<'PY'\n"):end]
    return code.replace(
        "path = Path('/usr/share/dvswitch/include/status.php')",
        "path = Path(os.environ['STATUS_CANDIDATE'])",
    )


def literal_assignment(tree: ast.Module, wanted: str) -> str:
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == wanted for target in node.targets
        ):
            return ast.literal_eval(node.value)
    raise AssertionError(f"missing installer template: {wanted}")


def main() -> None:
    code = embedded_python()
    tree = ast.parse(code)
    old_display = literal_assignment(tree, "old_v6_display")
    themed_master = literal_assignment(tree, "themed_master")
    themed_display = literal_assignment(tree, "themed_display")
    helpers = (
        "dvsButtonsDmrNetwork", "dvsButtonsDmrTalkgroup", "dvsButtonsDmrName",
        "dvsButtonsDmrSavedCardMode", "dvsButtonsDmrSavedNetwork",
        "dvsButtonsDmrCurrentMode", "dvsButtonsDmrSavedTalkgroup",
        "dvsButtonsDmrMasterHeading",
    )
    fixture = "<?php\ninclude_once dirname(dirname(__FILE__)).'/include/functions.php';\n"
    fixture += "// DVSwitch-Mode-Buttons: standalone DMR Master display v6\n"
    fixture += "".join(f"function {name}($value) {{ return ''; }}\n" for name in helpers)
    fixture += old_display + "\n"
    fixture += f"        if ($talkgroup === '') {{ return {themed_master} }}\n"
    fixture += f"        return {themed_display}\n}}\n?>\n"

    with tempfile.TemporaryDirectory() as directory:
        candidate = Path(directory) / "status.php"
        candidate.write_text(fixture)
        environment = os.environ.copy()
        environment["STATUS_CANDIDATE"] = str(candidate)
        subprocess.run([sys.executable, "-c", code], env=environment, check=True, capture_output=True, text=True)
        upgraded = candidate.read_text()
        assert "function dvsButtonsDmrRememberTalkgroup(" in upgraded
        assert "if ($isDmrMode && $talkgroup !== '') { dvsButtonsDmrRememberTalkgroup($talkgroup); }" in upgraded
        assert "$talkgroup = $isDmrMode ? dvsButtonsDmrTalkgroup($abinfo) : dvsButtonsDmrSavedTalkgroup();" in upgraded
        subprocess.run([sys.executable, "-c", code], env=environment, check=True, capture_output=True, text=True)
        assert candidate.read_text() == upgraded, "v6-to-current DMR card upgrade is not idempotent"

    print("PASS: installed v6 DMR card gains live DMR target persistence idempotently")


if __name__ == "__main__":
    main()
