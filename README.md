Not required but highly suggested to install my DVSwitch Repairs & Mods Repository 1st.
https://github.com/ke2hni/DVSwitch-Mods

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

Choose **1** to install the buttons or upgrade an existing installation to the current repository version. During that operation, the installer checks the BM and TGIF passwords in `/var/lib/dvswitch/dvs/var.txt`. If the alternate network's password is missing or still `passw0rd`, it prompts for that password and writes it into the generated `MMDVM_Bridge.<MODE>.ini` preset. <u>A blank password or the unchanged default stops the install as incomplete; it does not claim success or create a preset using the default credential.</u> The installer then installs the complete tested mode-button path:

- BM/TGIF MMDVM Bridge and Analog Bridge preset switching through the unified mode helper.
- Per-mode target persistence.
- A single-line dashboard control for tuning the active mode to a talkgroup or reflector ID. The field uses the existing `dvswitch.sh tune` command through a dedicated root helper; it does not use or install the separate DVS Mode Switcher application.
- Mode-specific dashboard Favorites. Only the active mode's entries appear beside Tune; **Edit** opens a mode selector so entries for any supported mode can be added, changed, or deleted. Selecting a favorite sends its TG/ref through the same Tune control. Favorites are stored in `/etc/dvswitch-mode-buttons/favorites.json` and remain available after uninstall/reinstall.
- Standalone DMR Master card rendering for BM, TGIF, and STFU; while YSF, P25, NXDN, or D-Star is active, it retains the last DMR talkgroup instead of displaying that mode’s tune ID.
- STFU friendly-name lookup using the BM talkgroup list.
- Friendly-name wrapping inside the DMR card.
- A saved DMR talkgroup that the dashboard updates only while the live mode is DMR/STFU; non-DMR mode IDs never replace it.
- The responsive DVSwitch dashboard layout, using the separate `dvswitch-display-layout.sh` script. The installer runs its read-only check and then its normal apply action during option 1, so the dashboard width is corrected along with the buttons.

The dashboard mode buttons and inline talkgroup/reflector tuner work whether they are installed before or after the
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
/usr/share/dvswitch/css/css.php
/usr/share/dvswitch/include/lh.php
/usr/share/dvswitch/include/localtx.php
/usr/share/dvswitch/include/system.php
```

BM/TGIF values are read from `var.txt`; missing credentials are requested interactively and never guessed.

## Read-only check

```bash
cd ~/DVSwitch-Mode-Buttons
sudo ./dvswitch-mode-buttons.sh --check
```

`--check` makes no changes. It validates prerequisites, checks that all files required by the bundled display-layout script are present, confirms the dashboard has either the original RX Monitor anchor or the supported DVSwitch-Mods relocated layout, checks the DMR card's connection-state patch target, and reports whether either network password in `var.txt` is missing or still the default. The tuner submits only validated IDs and invokes a dedicated helper with no command-line arguments; the helper reads the ID from standard input and runs `dvswitch.sh tune`. Favorites are filtered by the live selected mode. The editor's mode selector loads and saves each mode's own list; names and IDs are validated by a root-owned helper, and saves are atomic. For D-Star, YSF, P25, and NXDN, the tune confirmation and target persistence use DVSwitch's live mode when available, avoiding stale mode state after terminal mode changes. DMR submodes continue to use the saved Mode Buttons state. Version 1.0.0-test23 moves the existing RX Monitor button to the left side of the Favorites dropdown row, before Favorites, Edit, and Tune. Version 1.0.0-test24 bundles the existing responsive display-layout script and applies it during option 1; the installer records only layout substitutions it introduced, and uninstall reverses those substitutions without restoring whole dashboard snapshots. Test25 invokes the helper through Python and the layout installer through Bash so installation does not depend on executable bits surviving ZIP extraction. Favorites remain mode-specific and the editor can switch modes. It upgrades prior test8–test24 controls blocks. The DMR card remains populated with the current talkgroup while BM/TGIF reconnect and labels the network `Connecting` until MMDVM_Bridge reports a successful login; it also uses `$dmrstat` for the `Closing` and `Connection` checks. `--install` explicitly runs the same install/upgrade action as menu option 1. `--uninstall` explicitly runs menu option 2. Installation validates PHP syntax and restarts Apache. The install-order regression tests are `tests/test-rx-monitor-moved-anchor.py` and `tests/test_display_layout_integration.py`.

## Uninstall

```bash
sudo ./dvswitch-mode-buttons.sh
# Select 2) Uninstall
```

Uninstall removes both mode helpers, the target-state helper, tuner helper, endpoint, sudoers entry, dashboard controls block, presets, and saved state. If an older standalone DMR helper was backed up before consolidation, uninstall restores it. Before removing runtime files, it backs up the dashboard and bridge files and surgically removes only structurally recognized Mode Buttons changes from `index.php`, `status.php`, and `dvswitch.sh`. It also reverts only the responsive width/style substitutions first introduced by Mode Buttons, preserving other content in the five dashboard files. DMR rows are restored to the DVSwitch-Mods implementation when its helper is present, or to the factory rows otherwise. It never restores a whole-file snapshot over changes another installer made. If an owned block is incomplete or ambiguous, uninstall stops before changing shared files or removing helpers.

## Installed state and backups

```text
/etc/dvswitch-mode-buttons/dmr-presets/
/usr/local/sbin/dvswitch-mode-buttons
/usr/local/sbin/dvswitch-mode-targets
/usr/local/sbin/dvswitch-mode-tune
/usr/local/sbin/dvswitch-mode-favorites
/usr/share/dvswitch/dvswitch-mode-favorites.js
/usr/local/sbin/dvswitch-dmr-network -> /usr/local/sbin/dvswitch-mode-buttons (compatibility link)
/var/lib/dvswitch-mode-buttons/
/var/lib/dvswitch-mode-buttons/last-dmr-talkgroup (root-owned, Apache group-writable saved DMR target)
/var/lib/dvswitch-mode-buttons/display-layout-owned.json (layout edits owned by this installation)
/var/backups/dvswitch-mode-buttons/
```

The repository keeps `dvswitch-display-layout.sh` as a separate installer script. It updates `index.php`, `css/css.php`, `include/lh.php`, `include/localtx.php`, and `include/system.php`; the ownership helper stores the specific substitutions made by the Buttons install.

`/etc/dvswitch-mode-buttons/favorites.json` contains separate favorites for BM, TGIF, STFU, YSF, P25, NXDN, and D-Star. It is retained by uninstall so an upgrade or reinstall does not erase the user's lists.

The BM/TGIF network-switch code now lives in the same installed mode helper; the old DMR helper path remains as a compatibility symlink. `dvswitch-mode-targets` remains a separate runtime command because the patched `dvswitch.sh tune` path invokes it directly to save and retrieve targets. The state directory is `755` so Apache can read the card state. The saved DMR target is owned by `root:www-data` with mode `664`, allowing the status page to retain the live DMR talkgroup when the active mode changes. `mode-targets.json` remains private at `600`.

## Safety boundaries

This repository is for a fresh install of DVSwitch which should be configured before installing this repository. This was tested on the following hardware, Raspberry Pi 4 with Dedian 12 (Bookworm) using the last supplied ASL 3 image containing Debian 12 (Bookworm), Raspberry Pi 5 with Dedian 13 (Trixie) using the last supplied ASL 3 image containing Debian 13 (Trixie), Dell Wyse 3040 with Debian 12 (Bookworm). It does not require DVSwitch-Mods to be installed but it is Highly Suggested.

Tested in this order:

```text
pi4test → pi5test → node3040
```

Production testing requires explicit authorization.

## License

See [LICENSE](LICENSE).


<img width="1600" height="852" alt="Screenshot 2026-09-28 223729" src="https://github.com/user-attachments/assets/2dd939b1-a8e2-4071-bfc8-5031b00946d3" />
<img width="1600" height="852" alt="Screenshot 2026-09-28 223748" src="https://github.com/user-attachments/assets/264c340e-9fb7-46af-a9b9-b6f397e107e0" />
<img width="1600" height="852" alt="Screenshot 2026-09-28 223805" src="https://github.com/user-attachments/assets/396a44b9-c021-46c6-9d7c-7c18233d2436" />
<img width="1600" height="852" alt="Screenshot 2026-09-28 223821" src="https://github.com/user-attachments/assets/0b964808-9991-4e91-b399-03bf880682a0" />

