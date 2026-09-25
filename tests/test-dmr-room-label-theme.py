#!/usr/bin/env python3
"""Check the DMR Room label markup and its safe upgrade path."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = (ROOT / "dvswitch-mode-buttons.sh").read_text()
CARD_INSTALLER = (ROOT / "install-standalone-dmr-master-card.sh").read_text()


class DmrRoomLabelThemeTest(unittest.TestCase):
    def test_installed_card_emits_semantic_label_for_named_and_fallback_rows(self):
        self.assertIn("class=\\\"dvs-dmr-room-label\\\"", INSTALLER)
        self.assertIn('class="dvs-dmr-room-label"', CARD_INSTALLER)
        self.assertIn("if ($talkgroup === '')", CARD_INSTALLER)
        self.assertIn("dvsButtonsDmrMasterDisplay($master, $abinfo)", INSTALLER)

    def test_upgrade_migrates_plain_and_previously_formatted_labels(self):
        self.assertIn("plain_master =", INSTALLER)
        self.assertIn("old_formatted_master =", INSTALLER)
        self.assertIn("themed_master =", INSTALLER)
        self.assertIn("themed_display =", INSTALLER)
        self.assertIn("ERROR: DMR Room-label formatting is incomplete or ambiguous", INSTALLER)


if __name__ == "__main__":
    unittest.main()
