# DVSwitch Mode Buttons

Separate dashboard mode-selection project for DVSwitch.

This repository is a separate project from `DVSwitch-Mods`. The current test
release includes the dashboard mode buttons and the STFU network card v7.

The intended behavior is:

- Non-DMR buttons call `/opt/MMDVM_Bridge/dvswitch.sh mode MODE`.
- The installer detects the network in the user’s live `MMDVM_Bridge.ini`.
- A complete preset is saved for that current network.
- The alternate BM/TGIF preset is built from `/var/lib/dvswitch/dvs/var.txt`.
- A network button is installed only when its required configuration exists.
- Selecting BM or TGIF replaces the live INI while preserving its ownership and permissions,
  restarts the required DVSwitch services, selects DMR, and verifies the result.

The STFU card installer reads `StartTG` from `/opt/MMDVM_Bridge/DVSwitch.ini`,
including configuration lines with inline comments, and uses the BrandMeister
talkgroup list for the friendly name. It does not modify `functions.php`.

The separate dashboard duration repair belongs in `DVSwitch-Mods` and is not
part of this repository.

## Test

Run the checks before installing:

```bash
cd ~/DVSwitch-Mode-Buttons && sudo ./dvswitch-mode-buttons.sh --check
```

Install the STFU card separately when the mode-button installation is already
working:

```bash
cd ~/DVSwitch-Mode-Buttons && sudo ./install-stfu-card-v7.sh && sudo php -l /usr/share/dvswitch/include/status.php && sudo systemctl restart apache2
```

The installer creates a backup beside `status.php` and refuses to overwrite an
existing STFU card.
