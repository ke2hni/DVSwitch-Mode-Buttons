# DVSwitch Mode Buttons

Separate dashboard mode-selection project for DVSwitch.

Version 1.0.0-test1 is an initial `pi4test` development build. It is not part of
the `DVSwitch-Mods` repository.

The intended behavior is:

- Non-DMR buttons call `/opt/MMDVM_Bridge/dvswitch.sh mode MODE`.
- The installer detects the network in the user’s live `MMDVM_Bridge.ini`.
- A complete preset is saved for that current network.
- The alternate BM/TGIF preset is built from `/var/lib/dvswitch/dvs/var.txt`.
- A network button is installed only when its required configuration exists.
- Selecting BM or TGIF replaces the live INI while preserving its ownership and permissions,
  restarts the required DVSwitch services, selects DMR, and verifies the result.

The alternate-preset parser is intentionally pending exact validation against a real
`var.txt` file on `pi4test`; no password or configuration value is guessed.

## Test

```bash
cd ~/DVSwitch-Mode-Buttons
sudo ./dvswitch-mode-buttons.sh --check
```

Do not run `--install` until the `var.txt` format has been inspected and the alternate
preset has passed review.
