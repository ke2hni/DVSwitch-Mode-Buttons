#!/usr/bin/env bash
set -u

VERSION="1.0.0-test5"
INI="/opt/MMDVM_Bridge/MMDVM_Bridge.ini"
PRESET_DIR="/etc/dvswitch-mode-buttons"
MODE_CMD="/opt/MMDVM_Bridge/dvswitch.sh"

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "run with sudo"
[[ $# -eq 1 ]] || die "usage: $0 BM|TGIF"
network="${1^^}"
[[ $network == BM || $network == TGIF ]] || die "network must be BM or TGIF"
preset="$PRESET_DIR/MMDVM_Bridge.$network.ini"
[[ -f "$INI" ]] || die "missing $INI"
[[ -f "$preset" ]] || die "$network preset is not installed"
[[ -x "$MODE_CMD" ]] || die "missing executable $MODE_CMD"

owner="$(stat -c '%u' "$INI")"
group="$(stat -c '%g' "$INI")"
perms="$(stat -c '%a' "$INI")"
tmp="$(mktemp "${INI}.tmp.XXXXXX")" || die "could not create temporary INI"
trap 'rm -f "$tmp"' EXIT
cp "$preset" "$tmp" || die "could not copy $network preset"
chown "$owner:$group" "$tmp" || die "could not preserve INI ownership"
chmod "$perms" "$tmp" || die "could not preserve INI permissions"
mv -f "$tmp" "$INI" || die "could not replace live INI"
trap - EXIT

systemctl restart analog_bridge mmdvm_bridge || die "DVSwitch services failed to restart"
"$MODE_CMD" mode DMR >/tmp/dvswitch-mode-buttons-dmr.out 2>&1 || { cat /tmp/dvswitch-mode-buttons-dmr.out; die "DVSwitch DMR mode command failed"; }

address="$(awk '
  /^\[DMR Network\]/{insec=1;next} /^\[/{insec=0}
  insec && /^[[:space:]]*Address[[:space:]]*=/{sub(/^[^=]*=/,""); gsub(/[[:space:]]/,""); print; exit}
' "$INI")"
case "$network" in
  BM) [[ "$address" == *brandmeister* || "$address" == *repeater.net || "$address" == *3102* || "$address" == *3104* ]] || die "verification failed: live address is $address";;
  TGIF) [[ "$address" == *tgif* ]] || die "verification failed: live address is $address";;
esac
systemctl is-active --quiet analog_bridge mmdvm_bridge || die "DVSwitch service verification failed"
echo "PASS: DMR network switched to $network ($address)."
