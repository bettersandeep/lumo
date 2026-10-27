# Methodology

This document tells how we found the way to control WiZ bulbs from a Mac.
It is written in ASD-STE100 Simplified Technical English.

## Goal

The user had 2 WiZ smart bulbs.
The user controlled the bulbs with the WiZ app on iPhone and Android.
The goal was to control the same bulbs from a Mac with a small app.

## Tools

- REA, a reverse engineering tool, to get and examine the Android app.
- `adb` (Android Debug Bridge), to connect to the Android phone.
- `strings` and `grep`, to find text in the app code.
- Python and `nc`, to send test messages to the bulbs.
- `arp`, `ping` and `ifconfig`, to examine the network.

## Step 1: Test for a local API

A local API lets a device on the same network control the bulb without the cloud.
The WiZ local API on UDP port 38899 is already public.
Open source projects such as `pywizlight` and the Home Assistant WiZ integration use it.
We did not find the port number in the app.
Thus, we did a test for this API first, because it is the fastest method.
The replies from the bulbs confirm the port.

1. We sent a JSON message to UDP port 38899 at the broadcast address of the network.
   The message was `{"method":"getPilot","params":{}}`.
2. One bulb sent a reply.
   The reply gave the MAC address, the signal strength, the on or off state, the colour and the brightness.
3. We sent `{"method":"getSystemConfig","params":{}}`.
   The bulb sent its model (`ESP25_SHRGB_01`) and its firmware version (1.38.0).
4. We sent `{"method":"setPilot","params":{"state":true}}`.
   The bulb sent `{"success":true}`.

Result: the bulb accepts commands on the local network.
It does not need the cloud and it does not need a password.

Note: the broadcast address `255.255.255.255` gave the error "No route to host" on the Mac.
The broadcast address of the subnet (for example `192.168.1.255`) worked.

## Step 2: Examine the WiZ app

A test on 1 bulb does not show which commands the app uses.
Thus, we examined the app to confirm the protocol.

1. We connected the Android phone to the Mac with USB.
2. We found the app package with `adb shell pm list packages`.
   The package is `com.wizconnected.wiz2`.
3. We used REA to copy the full app from the phone (the base APK and 3 split APKs).
4. We listed the largest files in the APKs.
   We found `libflutter.so` and `libapp.so`.
   This shows that the app is made with Flutter.
   In a Flutter app, all the app logic is compiled into `libapp.so`.
5. We extracted the text strings from `libapp.so` with `strings`.
6. We searched the strings for the names of WiZ commands.
   We found `setPilot`, `getPilot`, `syncPilot`, `setState`, `pulse`, `reboot`, `reset`, `registration` and `firstBeat`.
7. We also found `UdpHmacUtil`, `UdpSecurityLevelEnum` and a database column `udpSigningKey`.
   This shows that the app can sign local UDP commands with HMAC.
   Our bulbs accepted unsigned commands.
   Thus, we did not examine the signing process.

Result: the app uses the same JSON commands on UDP port 38899.

Note: the scene names are not in the app code.
The app downloads them.
Thus, we used the standard WiZ scene numbers (1 to 32).
We tested scene 5 (Fireplace) on a bulb.
The bulb accepted it and `getPilot` then showed `"sceneId":5`.

## Step 3: Find the second bulb

The user had 2 bulbs, but only 1 bulb sent a reply.

1. We sent the message 3 times to the broadcast address.
   Only 1 bulb sent a reply.
2. We sent the message to all 254 addresses in the network, one at a time.
   Only 1 bulb sent a reply.
3. We examined the network table of the phone with `adb shell ip neigh`.
   One address showed `FAILED`.
4. We did a ping sweep from the phone.
   After the sweep, the second bulb showed in the network table of the phone with a WiZ MAC address (it starts with `98:77:d5`).
5. We sent `getPilot` to the second bulb from the phone with `nc`.
   The bulb sent a reply.

Result: the second bulb is on the network and it accepts commands.
But it does not reply to broadcast messages.

## Step 4: Find why the Mac cannot reach the second bulb

1. On the Mac, `arp -an` showed the second bulb as `(incomplete)`.
   This means that the Mac sent an ARP request (a broadcast), but the bulb did not reply.
   Without the hardware address, the Mac cannot send any message to the bulb.
2. The phone had the hardware address in its cache, from an earlier connection.
   Thus, the phone could reach the bulb.

Cause: the bulb does not reply to broadcast frames while its Wi-Fi is in power save.
This includes ARP requests.

Fix: we added a static ARP entry on the Mac.

```sh
sudo arp -d <bulb-ip> ifscope en0
sudo arp -s <bulb-ip> <bulb-mac> ifscope en0
```

Note: an entry without `ifscope en0` did not work.
macOS kept a second, incomplete entry for `en0` and used that entry.

After this fix, the Mac found both bulbs.
A LaunchDaemon adds the entry again at each boot and at each network change.

## Step 5: Find why commands from the Mac failed

Some messages from the Mac failed with "No route to host".
This also occurred for the first bulb, and for `ping`.
The routing table was correct.

Cause: macOS Local Network privacy.
macOS blocks local network access for an app that does not have permission.
A program that is not in an app bundle cannot ask for this permission.

Fix: we put the program in an app bundle (`Lumo.app`).
The `Info.plist` file has the key `NSLocalNetworkUsageDescription`.
Then macOS asks the user for permission.

## Step 6: Make the app

We made the app with Swift and AppKit only.
It does not use other libraries.

- Discovery: Lumo sends `getPilot` to the broadcast address and to all addresses in the /24 network, 3 times.
  It keeps each IP address that sends a reply, with the MAC address from the reply.
  Lumo searches when it starts and when the Mac wakes.
  If it finds no bulbs, it searches again every 30 seconds, because the network is often not ready at login.
- Control: each menu item sends one `setPilot` command.
  - On and off: `{"state":true}` or `{"state":false}`.
  - Brightness: `{"dimming":10}` to `{"dimming":100}`.
  - White temperature: `{"temp":2200}` to `{"temp":6500}`.
  - Colour: `{"r":255,"g":0,"b":0}`.
  - Scene: `{"sceneId":5}`.
- Colour wheel: the angle gives the hue and the distance from the centre gives the saturation.
  While the user drags, Lumo sends a maximum of approximately 12 commands each second.
- Aliases: Lumo keeps each name with the MAC address of the bulb.
  Thus, the name stays correct when the IP address changes.
- Start at login: Lumo uses `SMAppService.mainApp.register()`.
- Scene checkmark: when the menu opens, Lumo sends `getPilot` to each bulb.
  The `sceneId` in the reply shows the scene that is on.
- Presets: Lumo changes a `getPilot` reply into `setPilot` params.
  It keeps `sceneId` and `speed` for a scene, `temp` for white, or `r`, `g`, `b`, `c` and `w` for a colour, with `dimming`.
- Schedule: each rule has a start time and an end time.
  At the start time, Lumo saves the state of each bulb as a preset and applies the preset of the rule.
  At the end time, Lumo applies the saved state.
  A timer checks the rules every 5 seconds, so a rule that was due while the Mac slept runs when the Mac wakes.

## Summary of evidence

| Finding | Evidence | Type |
|---|---|---|
| Bulbs accept JSON on UDP 38899 | Port from public documentation; replies from both bulbs to `getPilot` and `setPilot` | Observed |
| The WiZ app uses the same commands | Command names in `libapp.so` | Static |
| The app can sign UDP commands | `UdpHmacUtil`, `udpSigningKey` in `libapp.so` | Static |
| Scene IDs | Scene 5 accepted and reported by `getPilot` | Observed (1 of 32 scenes) |
| Second bulb ignores broadcasts | No reply to broadcast; `(incomplete)` ARP; reply to unicast from phone | Observed |
| Local Network privacy blocks the Mac | "No route to host" with a correct route; fixed by an app bundle | Observed |

## Unknowns

- We did not examine how the app signs commands.
- We did not test the 31 scenes other than scene 5.
- We did not test bulbs other than full colour bulbs.
