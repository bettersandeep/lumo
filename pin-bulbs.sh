#!/bin/sh
# Pins the hardware (MAC) addresses of WiZ bulbs on this Mac.
# Some bulbs ignore ARP broadcasts while their Wi-Fi is in power save, so the Mac
# cannot reach them. A static ARP entry fixes this. A LaunchDaemon adds the entries
# again at each boot and network change, because macOS forgets them.
#
# Usage:
#   ./pin-bulbs.sh                 pin the bulbs that Lumo finds now
#   ./pin-bulbs.sh IP=MAC ...      pin these bulbs, e.g. 192.168.1.50=98:77:d5:aa:bb:cc
#   ./pin-bulbs.sh --remove        remove the LaunchDaemon
set -e

LABEL=local.lumo.arp
PLIST=/Library/LaunchDaemons/$LABEL.plist
IFACE=$(route -n get default | awk '/interface:/ { print $2 }')

if [ "$1" = "--remove" ]; then
  sudo launchctl bootout system/$LABEL 2>/dev/null || true
  sudo rm -f $PLIST
  echo "Removed $LABEL. The current ARP entries stay until the next restart."
  exit 0
fi

if [ $# -eq 0 ]; then
  # Run through `open` so that Lumo's Local Network permission applies.
  out=$(mktemp)
  open -n -W --stdout "$out" /Applications/Lumo.app --args --discover
  set -- $(awk '{ m = $2; gsub(/../, "&:", m); sub(/:$/, "", m); print $1 "=" m }' "$out")
  rm -f "$out"
  [ $# -gt 0 ] || { echo "Lumo found no bulbs. Give them as IP=MAC." >&2; exit 1; }
fi

for b in "$@"; do
  echo "$b" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}=([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$' \
    || { echo "Not IP=MAC: $b" >&2; exit 1; }
done

cmd="until /usr/sbin/ipconfig getifaddr $IFACE >/dev/null; do sleep 5; done; \
for b in $*; do /usr/sbin/arp -d \${b%=*} ifscope $IFACE; /usr/sbin/arp -s \${b%=*} \${b#*=} ifscope $IFACE; done"

tmp=$(mktemp)
cat > "$tmp" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array><string>/bin/sh</string><string>-c</string><string>$cmd</string></array>
<key>RunAtLoad</key><true/>
<key>WatchPaths</key><array><string>/var/run/resolv.conf</string></array>
</dict></plist>
EOF
plutil -lint -s "$tmp"

sudo launchctl bootout system/$LABEL 2>/dev/null || true
sudo install -m 644 -o root -g wheel "$tmp" $PLIST
sudo launchctl bootstrap system $PLIST
rm -f "$tmp"

echo "Pinned on $IFACE:"
for b in "$@"; do echo "  ${b%=*}  ${b#*=}"; done
