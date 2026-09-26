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

    def test_non_dmr_modes_use_the_saved_dmr_target(self):
        self.assertIn("dvsButtonsDmrSavedTalkgroup()", INSTALLER)
        self.assertIn("dvsButtonsDmrRememberTalkgroup($talkgroup)", INSTALLER)
        self.assertIn("dvsButtonsDmrCurrentMode($abinfo)", INSTALLER)
        self.assertIn("last-dmr-talkgroup", INSTALLER)
        self.assertIn("display v6", INSTALLER)
        self.assertIn("$isDmrMode = in_array($liveMode, array('DMR', 'BM', 'TGIF', 'STFU'), true);", INSTALLER)
        self.assertIn("if ($isDmrMode && $talkgroup !== '') { dvsButtonsDmrRememberTalkgroup($talkgroup); }", INSTALLER)
        self.assertIn("chown root:www-data /var/lib/dvswitch-mode-buttons/last-dmr-talkgroup", INSTALLER)
        self.assertIn("chmod 664 /var/lib/dvswitch-mode-buttons/last-dmr-talkgroup", INSTALLER)
        target_helper = (ROOT / "dvswitch-mode-targets").read_text()
        self.assertIn('"$STATE_DIR/last-dmr-talkgroup"', target_helper)
        self.assertIn('"$mode" == BM || "$mode" == TGIF || "$mode" == STFU', target_helper)
        self.assertIn('chown root:www-data "$last_dmr_tmp"', target_helper)
        self.assertIn('chmod 664 "$last_dmr_tmp"', target_helper)

    def test_upgrade_migrates_plain_and_previously_formatted_labels(self):
        self.assertIn("plain_master =", INSTALLER)
        self.assertIn("old_formatted_master =", INSTALLER)
        self.assertIn("themed_master =", INSTALLER)
        self.assertIn("themed_display =", INSTALLER)
        self.assertIn("ERROR: DMR Room-label formatting is incomplete or ambiguous", INSTALLER)


if __name__ == "__main__":
    unittest.main()
