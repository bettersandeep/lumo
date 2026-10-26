# Lumo

Lumo is a small macOS menu bar app that controls WiZ smart bulbs.
It talks to the bulbs directly on your local network.
It does not use the WiZ cloud and it does not need a WiZ account.

![Lumo demo](docs/demo.gif)

## Features

- Find all WiZ bulbs on your network.
- Turn bulbs on and off, one at a time or all together.
- Set brightness and white colour temperature (warm to cool).
- Pick a colour from a colour wheel or from 12 common colours.
- Start one of the 32 standard WiZ scenes. The menu shows the scene that is on now.
- Save the state of a bulb as a preset.
- Apply presets by time of day (schedule).
- Give each bulb a name (alias).
- Start at login.

## Requirements

- macOS 14 or later.
- Xcode Command Line Tools (`xcode-select --install`).
- WiZ bulbs on the same network as your Mac.

## Build and install

```sh
./build.sh
```

The script compiles the app, draws the icon, and installs `Lumo.app` in `/Applications`.
Then it starts the app.

When macOS asks if Lumo can find devices on your local network, click **Allow**.
If you do not see this request, go to System Settings > Privacy & Security > Local Network and turn on Lumo.

## Use

Click the bulb icon in the menu bar.
Each bulb has its own submenu.
If there is more than one bulb, the **All lights** submenu controls all of them.
To give a bulb a name, open its submenu and click **Rename…**.

### Presets

1. Set a bulb as you like it, with the menu or with the WiZ app.
2. Open the submenu of the bulb and click **Save as Preset…**.
3. Type a name and click **Save**.

Lumo saves the on or off state, the brightness, and the colour, white temperature or scene.
To apply a preset, open **Presets** in the submenu of a bulb or in **All lights**.
To delete a preset, use **Presets > Delete**.
When you delete a preset, Lumo also deletes the schedule rules that use it.

### Schedule

1. Click **Schedule > Add Rule…**.
2. Select the start time (**From**), the end time (**To**), the lights and the preset.
3. Click **Save**.

The schedule works like Screen Time downtime.
At the start time, Lumo saves the state of the lights and applies the preset.
At the end time, Lumo puts the lights back to the saved state.
A rule can cross midnight, for example from 10:00 PM to 7:00 AM.

Lumo applies a rule one time.
If you change a light by hand during the rule, Lumo does not change it back until the end time.
If the Mac is asleep or Lumo is closed at the start time, Lumo applies the rule when the Mac wakes or Lumo starts, if the end time has not passed.
If the Mac is asleep at the end time, Lumo puts the lights back when the Mac wakes.

A rule for one bulb is stronger than a rule for **All lights**.

To delete a rule, open the rule and click **Delete**.

To list the bulbs from the terminal:

```sh
/Applications/Lumo.app/Contents/MacOS/Lumo --discover
```

## Troubleshooting

### A bulb works in the WiZ app but Lumo does not find it

Some bulbs do not reply to broadcast messages while their Wi-Fi is in power save.
This also includes ARP requests, so the Mac cannot find the hardware address of the bulb.
You can see this problem with `arp -an`: the bulb shows as `(incomplete)`.

A bulb can work for some time and then stop, when the Mac forgets its hardware address.

To fix it, pin the hardware address of each bulb on the Mac:

```sh
./pin-bulbs.sh
```

The script pins the bulbs that Lumo finds now.
It installs a LaunchDaemon that adds the entries again at each boot and network change.
It asks for your password.

If Lumo does not find a bulb, give its IP and MAC address.
Find them in your router, or with a ping sweep from another device.

```sh
./pin-bulbs.sh 192.168.1.50=98:77:d5:aa:bb:cc 192.168.1.51=98:77:d5:aa:bb:dd
```

Run the script again when you add a bulb.
To remove the LaunchDaemon, run `./pin-bulbs.sh --remove`.

Also reserve the IP address of each bulb in your router (DHCP reservation).
If the router gives a bulb a new IP address, the pinned entry is wrong.

### Commands do nothing

Make sure that Lumo has Local Network permission (see above).
Without it, macOS blocks the messages with "No route to host".

## How it works

WiZ bulbs accept JSON commands over UDP on port 38899.
For example, this command turns a bulb off:

```json
{"method":"setPilot","params":{"state":false}}
```

To read how we found this, see [docs/METHODOLOGY.md](docs/METHODOLOGY.md).

## Limits

- Lumo looks for bulbs only in /24 networks (for example `192.168.1.0` to `192.168.1.255`).
- The WiZ app can sign local commands (HMAC).
  Lumo does not sign commands.
  If WiZ turns on signing for your home or in a new firmware, Lumo can stop working.
- Lumo was tested with WiZ full colour bulbs (module `ESP25_SHRGB_01`, firmware 1.38.0).

## Demo animation

`docs/demo.gif` is drawn by `docs/demo.swift`.
To make it again:

```sh
mkdir -p build && swift icon.swift build/icon.png && swift docs/demo.swift build/icon.png docs/demo.gif
```

## Licence

MIT. See [LICENSE](LICENSE).

## Disclaimer

Lumo is not made by or related to WiZ or Signify.
WiZ is a trademark of its owner.
