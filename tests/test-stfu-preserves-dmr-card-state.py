#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Ensure selecting STFU leaves the last BM/TGIF card selection intact."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HELPER = (ROOT / "dvswitch-mode-buttons").read_text()
state_block = HELPER.split('if [[ "$mode" == BM || "$mode" == TGIF ]]; then', 1)[1].split("\nfi", 1)[0]
assert '"$DMR_NETWORK_FILE"' in state_block
assert '"$DMR_CARD_MODE_FILE"' in state_block
assert 'elif [[ "$mode" == STFU' not in HELPER
assert 'BM > "$DMR_NETWORK_FILE"' not in HELPER
assert 'STFU > "$DMR_CARD_MODE_FILE"' not in HELPER
print("PASS: STFU selection preserves the previous BM/TGIF DMR card state")
