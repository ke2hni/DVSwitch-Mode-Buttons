# DVSwitch Mode Buttons

<div align="center">

## Seven-mode dashboard selection for DVSwitch

**BrandMeister · TGIF · STFU · YSF · P25 · NXDN · D-Star**

One manager script installs, upgrades, checks, and removes the complete mode-button modification.

</div>

---

## What this adds

DVSwitch Mode Buttons adds a centered horizontal button bar directly below the dashboard title and above the **RX Monitor** button.

| Mode | Function |
|---|---|
| **BM** | Select the BrandMeister DMR network |
| **TGIF** | Select the TGIF DMR network |
| **STFU** | Select STFU |
| **YSF** | Select YSF |
| **P25** | Select P25 |
| **NXDN** | Select NXDN |
| **D-Star** | Select D-Star |

The selected mode is highlighted in green and restored after a dashboard refresh by reading live DVSwitch status.

## Features

- One menu-driven installer and uninstaller.
- Completes or upgrades partial installations.
- Preserves the tested dashboard location and button colors.
- Uses the repository’s verified mode-switching helpers and endpoint.
- Supports BM/TGIF preset creation and network switching.
- Restarts the required DVSwitch services after a BM/TGIF network change.
- Updates the DVSwitch-Mods DMR network state when that state file already exists.
- Does **not** modify `Analog_Bridge.ini`.
- Does **not** add TG/ref persistence, a startup service, or Local Activity changes.
- Creates uninstall backups under `/var/backups/dvswitch-mode-buttons/`.
- Validates Bash, PHP, sudoers, dashboard, and DMR-helper requirements.

## Requirements

Run the manager as root from a checked-out copy of this repository on a DVSwitch node.

The installer verifies these existing DVSwitch paths:

```text
/usr/share/dvswitch/index.php
/var/lib/dvswitch/dvs/var.txt
/opt/MMDVM_Bridge/dvswitch.sh
/opt/MMDVM_Bridge/MMDVM_Bridge.ini
```

The repository history must be available because the manager installs the verified source revisions directly from Git.

## Quick install

```bash
cd ~/DVSwitch-Mode-Buttons
chmod +x dvswitch-mode-buttons.sh
sudo ./dvswitch-mode-buttons.sh
```

Choose:

```text
1) Install / upgrade
2) Uninstall
3) Exit
```

After installation, if the dashboard was already open, refresh that browser tab with **F5** so the new buttons appear.

## Recommended check first

The check mode makes no changes:

```bash
cd ~/DVSwitch-Mode-Buttons
sudo ./dvswitch-mode-buttons.sh --check
```

A clean node reports:

```text
PASS: prerequisites verified; ready for first installation; no files changed.
```

A complete installation reports:

```text
ALREADY INSTALLED: unified DVSwitch mode buttons are complete; no files changed.
```

A partial or older installation is detected and reported as ready for completion or upgrade.

## Direct commands

The menu is the normal interface, but direct administrative commands are also supported:

```bash
# Verify without changing files
sudo ./dvswitch-mode-buttons.sh --check

# Install or upgrade
sudo ./dvswitch-mode-buttons.sh --install

# Remove the modification
sudo ./dvswitch-mode-buttons.sh --uninstall
```

## Installed components

```text
/usr/local/sbin/dvswitch-mode-buttons
/usr/local/sbin/dvswitch-dmr-network
/usr/share/dvswitch/dvswitch-mode-buttons.php
/etc/sudoers.d/dvswitch-mode-buttons
/etc/dvswitch-mode-buttons/
```

The dashboard block is installed in:

```text
/usr/share/dvswitch/index.php
```

## Uninstall behavior

The uninstall option removes only the mode-button modification:

- Dashboard mode-button block.
- Mode-switch helpers.
- Dashboard endpoint.
- Mode-button sudoers file.
- BM/TGIF preset directory.
- Mode-button state directory.

Affected files and directories are backed up under a timestamped directory in:

```text
/var/backups/dvswitch-mode-buttons/
```

The dashboard is validated after removal, and unrelated DVSwitch files are preserved.

## Safety boundaries

This project is limited to dashboard mode selection and required BM/TGIF network switching support.

It does not:

- Replace or edit `/opt/Analog_Bridge/Analog_Bridge.ini`.
- Modify individual network cards.
- Modify Gateway Activity or Local Activity rendering.
- Install a systemd startup service.
- Add last-target TG/ref persistence.
- Replace the DVSwitch-Mods repository.

## Testing order

```text
pi4test → pi5test → node3040 → node68425
```

Do not install on the production node until the test nodes have passed.

## Repository workflow

```bash
cd ~/DVSwitch-Mode-Buttons
git pull --ff-only
sudo ./dvswitch-mode-buttons.sh --check
sudo ./dvswitch-mode-buttons.sh --install
```

Keep the manager executable and stored with Unix LF line endings.

## License

See [LICENSE](LICENSE).
