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

### 2. Use the installer menu

Run the manager without arguments:

```bash
sudo ./dvswitch-mode-buttons.sh
```

`dvswitch-mode-buttons.sh` is the primary installer. It creates the BM/TGIF presets and installs the complete tested mode-button path:

- BM/TGIF MMDVM Bridge and Analog Bridge preset switching through the unified mode helper.
- Per-mode target persistence.
- Standalone DMR Master card rendering for BM, TGIF, and STFU.
- STFU friendly-name lookup using the BM talkgroup list.
- Friendly-name wrapping inside the DMR card.
- Apache-readable DMR card state that remains writable only by root.

The standalone DMR card is self-contained and does not require the `DVSwitch-Mods` repository.
Its BM, TGIF, and STFU cards display the `Room` label above the current
network/talkgroup name.

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

## Check and install

```bash
cd ~/DVSwitch-Mode-Buttons
sudo ./dvswitch-mode-buttons.sh --check
sudo ./dvswitch-mode-buttons.sh --install
```

The check makes no changes. Installation also validates PHP syntax and restarts Apache.

## Uninstall

```bash
sudo ./dvswitch-mode-buttons.sh --uninstall
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
