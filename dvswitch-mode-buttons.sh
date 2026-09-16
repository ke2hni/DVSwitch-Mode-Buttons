#!/usr/bin/env bash
set -u

VERSION="1.0.0-test1"
INI="/opt/MMDVM_Bridge/MMDVM_Bridge.ini"
VAR="/var/lib/dvswitch/dvs/var.txt"
PRESET_DIR="/etc/dvswitch-mode-buttons"
HELPER="/usr/local/sbin/dvswitch-mode-buttons"
ENDPOINT="/usr/share/dvswitch/dvswitch-mode-buttons.php"

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "run with sudo"
[[ -f "$INI" ]] || die "missing $INI"

mode="check"
[[ ${1:-} == "--install" ]] && mode="install"
[[ ${1:-} == "--check" || ${1:-} == "" ]] || die "usage: $0 [--check|--install]"

network="$(awk '
  /^\[DMR Network\]/{insec=1;next} /^\[/{insec=0}
  insec && /^[[:space:]]*Address[[:space:]]*=/{sub(/^[^=]*=/,""); gsub(/[[:space:]]/,""); print; exit}
' "$INI")"
case "$network" in
  *brandmeister*|*repeater.net|*3102*|*3104*) default_net=BM;;
  *tgif*) default_net=TGIF;;
  *) default_net=UNKNOWN;;
esac

if [[ $mode == check ]]; then
  echo "DVSwitch Mode Buttons $VERSION"
  echo "MMDVM_Bridge.ini: $INI"
  echo "Current DMR network: $default_net ($network)"
  [[ -f "$VAR" ]] && echo "DVSwitch var.txt: found" || echo "DVSwitch var.txt: not found"
  echo "PASS: installer prerequisites checked; no files changed."
  exit 0
fi

install -d -m 700 -o root -g root "$PRESET_DIR"
cp -p "$INI" "$PRESET_DIR/MMDVM_Bridge.$([[ $default_net == BM ]] && echo BM || echo TGIF).ini"

echo "The initial version creates the current-network preset now."
echo "The alternate BM/TGIF preset requires the exact var.txt format and will be completed after pi4test inspection."
echo "Current-network preset created in $PRESET_DIR."
echo "PASS: initial test files installed."
