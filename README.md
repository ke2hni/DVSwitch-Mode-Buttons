# DVSwitch Mode Buttons

Seven-mode dashboard selection for DVSwitch: **BM · TGIF · STFU · YSF · P25 · NXDN · D-Star**.

## 🚀 Quick start — install everything

### 1. Download the complete repository

Run this from your home directory:

```bash
cd ~ && git clone https://github.com/ke2hni/DVSwitch-Mode-Buttons.git && cd DVSwitch-Mode-Buttons
```

Already downloaded it? Update it instead:

```bash
cd ~/DVSwitch-Mode-Buttons && git pull --ff-only
```

You can also download one ZIP containing the entire repository from the
green **Code** button on GitHub or use the
**[direct ZIP download](https://github.com/ke2hni/DVSwitch-Mode-Buttons/archive/refs/heads/main.zip)**.
Do not download the scripts individually.

### 2. Install or upgrade

Run the installer without arguments to open its three-option menu:

```bash
sudo ./dvswitch-mode-buttons.sh
```

```text
1) Install / upgrade
2) Uninstall
3) Exit
```

Choose **1** to install the buttons or upgrade an existing installation to the current repository version. During that operation, the installer checks the BM and TGIF passwords in `/var/lib/dvswitch/dvs/var.txt`. If the alternate network's password is missing or still `passw0rd`, it prompts for that password and writes it into the generated `MMDVM_Bridge.<MODE>.ini` preset. A blank password or the unchanged default stops the install as incomplete; it does not claim success or create a preset using the default credential. The installer then installs the complete tested mode-button path:

- BM/TGIF MMDVM Bridge and Analog Bridge preset switching through the unified mode helper.
- Per-mode target persistence.
- Standalone DMR Master card rendering for BM, TGIF, and STFU.
- STFU friendly-name lookup using the BM talkgroup list.
- Friendly-name wrapping inside the DMR card.
- Apache-readable DMR card state that remains writable only by root.

The dashboard mode buttons work whether they are installed before or after the
DVSwitch-Mods RX Monitor position modification. If RX Monitor has already moved
to the left status column, the installer places the mode buttons in the vacated
centered area and preserves the relocated RX Monitor control.

The standalone DMR card is self-contained and does not require the `DVSwitch-Mods` repository.
Its BM, TGIF, and STFU cards display the `Room` label above the current
network/talkgroup name.
The label keeps its light-theme color in the standard dashboard. When the
DVSwitch-Mods Dark Mode overlay is installed, its theme stylesheet changes the
label to a readable light color; this works whether Dark Mode is installed
before or after Mode Buttons.

## Requirements

Run from a configured DVSwitch node as root. The installer requires:

```text
/opt/MMDVM_Bridge/MMDVM_Bridge.ini
/opt/MMDVM_Bridge/dvswitch.sh
/opt/Analog_Bridge/Analog_Bridge.ini
/var/lib/dvswitch/dvs/var.txt
/usr/share/dvswitch/index.php
/usr/share/dvswitch/include/status.php
```

BM/TGIF values are read from `var.txt`; missing credentials are requested interactively and never guessed.

## Read-only check

```bash
cd ~/DVSwitch-Mode-Buttons
sudo ./dvswitch-mode-buttons.sh --check
```

`--check` makes no changes. It validates prerequisites, confirms the dashboard has either the original RX Monitor anchor or the supported DVSwitch-Mods relocated layout, and reports whether either network password in `var.txt` is missing or still the default. `--install` explicitly runs the same install/upgrade action as menu option 1. `--uninstall` explicitly runs menu option 2. Installation validates PHP syntax and restarts Apache. The install-order regression test is `tests/test-rx-monitor-moved-anchor.py`.

## Uninstall

```bash
sudo ./dvswitch-mode-buttons.sh
# Select 2) Uninstall
```

Uninstall removes both mode helpers, the target-state helper, endpoint, sudoers entry, dashboard button block, presets, and saved state. If an older standalone DMR helper was backed up before consolidation, uninstall restores it. Before removing runtime files, it backs up the dashboard and bridge files and surgically removes only structurally recognized Mode Buttons changes from `index.php`, `status.php`, and `dvswitch.sh`. DMR rows are restored to the DVSwitch-Mods implementation when its helper is present, or to the factory rows otherwise. It never restores a whole-file snapshot over changes another installer made. If an owned block is incomplete or ambiguous, uninstall stops before changing shared files or removing helpers.

## Installed state and backups

```text
/etc/dvswitch-mode-buttons/dmr-presets/
/usr/local/sbin/dvswitch-mode-buttons
/usr/local/sbin/dvswitch-mode-targets
/usr/local/sbin/dvswitch-dmr-network -> /usr/local/sbin/dvswitch-mode-buttons (compatibility link)
/var/lib/dvswitch-mode-buttons/
/var/backups/dvswitch-mode-buttons/
```

The BM/TGIF network-switch code now lives in the same installed mode helper; the old DMR helper path remains as a compatibility symlink. `dvswitch-mode-targets` remains a separate runtime command because the patched `dvswitch.sh tune` path invokes it directly to save and retrieve targets. The state directory is `755` so Apache can read the card state. State files are root-owned; `mode-targets.json` remains private at `600`.

## Safety boundaries

This repository does not modify `node68425` remotely, individual network cards, Local Activity rendering, or unrelated DVSwitch-Mods changes. It does not require DVSwitch-Mods to be installed.

Test in this order:

```text
pi4test → pi5test → node3040 → node68425
```

Production testing requires explicit authorization.

## License

See [LICENSE](LICENSE).
