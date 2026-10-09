# VibeScreen

**A one-click Retina portrait desktop switch for Vibe Coding on your Mac through NetEase UU Remote from a mobile device.**

[中文说明](README.zh-CN.md) · [Download / Releases](https://github.com/Jhe1004/vibe-screen/releases)

![Mobile devices connected to a Mac for Vibe Coding](assets/portrait-vibe.svg)

## Why this exists

I use mobile devices with UU Remote to control my Mac and work with AI coding tools. A landscape Mac desktop occupies only the middle of a portrait device, leaving empty space and making the editor, terminal, and chat harder to read.

VibeScreen gives the Mac a portrait-shaped desktop. Click once to switch; click again to restore the original display settings. UU Remote continues to handle the remote connection. This app only changes the desktop layout.

## Sharper text in v0.3.0

The earlier build rendered only 744 × 1134 pixels, making text softer when enlarged on a mobile device. v0.3.0 corrects the HiDPI virtual mode dimensions. It keeps the same desktop and text size while rendering twice as many pixels in each direction, for four times the pixel count. The app verifies the actual 2× framebuffer before reporting success and restores if that mode is unavailable.

Local Mac testing verifies the mode and restoration. The UU client must still transmit sufficient resolution and quality; end-to-end clarity depends on its capture path and settings.

v0.4.0 renames the project from iPad Portrait Vibe to **VibeScreen** and broadens its purpose to mobile remote Vibe Coding. It retains the output and restoration behavior of v0.3.1. Automatic device detection and additional aspect-ratio presets are not implemented.

## Use it

1. Download the ZIP from **Releases**, unzip it, and drag **VibeScreen.app** into **Applications**. The app is self-contained.
2. Connect to your Mac through UU Remote, keeping the mobile device in portrait orientation.
3. Open the app and click **切换到高清竖屏** (Switch to Retina portrait).
4. Check the picture and pointer alignment. If UU still shows a landscape view, select **VibeScreen** in its display selector, where available.
5. Click **画面正常，保持竖屏** (Keep portrait) when everything looks right. Without confirmation, the app restores the desktop after approximately **120 seconds**.
6. Click **恢复正常电脑模式** (Restore normal desktop) to switch back. Closing the app also requests restoration.

The menu bar provides a second route to the switch and **恢复并退出** (Restore and quit).

## Current support

| Item | Current status |
| --- | --- |
| macOS | Minimum deployment target: macOS 14. Tested on macOS 26.5. Other versions require testing. |
| Macs | Universal executable with arm64 and x86_64 slices. Runtime testing has been on an M4 MacBook Air. Intel Macs have not been runtime-tested. |
| Display setup | One display, with existing mirroring disabled. Multiple displays are rejected before changes are made. |
| Device fit | A fixed portrait preset; no automatic device detection or arbitrary aspect-ratio matching. Some devices may retain empty space. |
| Desktop mode | **744 × 1134 desktop points / 1488 × 2268 framebuffer pixels, Retina 2×**. Locally verified; delivered sharpness also depends on UU quality and bitrate settings. |
| UU Remote | The author reports good experience on their iPad mini 7 and a phone through UU Remote. The phone model has not been recorded. Other devices and client versions still require testing. |
| UI language | Chinese buttons, with English translations in these instructions. |

The Mac's physical landscape screen may show empty space on its sides while mirroring the portrait desktop. The goal is to make the remote portrait workspace fit a mobile device.

## Downloaded-app checks

The current public beta uses **local ad-hoc signing**, not Apple Developer ID signing or notarization. macOS may block a downloaded copy. If you trust the source and have checked the archive, follow [Apple's instructions for opening the app](https://support.apple.com/en-us/102445), or build it locally from the source. The project does not ask you to disable Gatekeeper globally.

Archives include `SHA256SUMS.txt` for integrity checks. The [Apple distribution documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) describes the Developer ID and notarization route for future releases.

## Build from source

Install Apple's Xcode Command Line Tools, then run:

```bash
git clone https://github.com/Jhe1004/vibe-screen.git
cd vibe-screen
bash build.sh
open "build/VibeScreen.app"
```

To create the universal ZIP and checksums:

```bash
bash package.sh
```

`build.sh` accepts an output directory. `package.sh` accepts build and distribution directories. CI builds and packages the app; CI does **not** change any display settings. No external library is needed.

## Restoration and local data

A helper process owns the virtual display and runs the confirmation timer. The app records the original display mode before changing anything, then verifies restoration after the helper exits. Closing the control pipe or losing the parent process requests restoration. Display configuration is requested only for the app's lifetime.

Local recovery records are stored in:

```text
~/Library/Application Support/VibeScreen/01_runs/
```

Pre-rename records remain in the original `iPad Portrait Vibe/01_runs/` folder. The original bundle identifier is retained to preserve app identity.

Each run gets a new numbered folder. Records contain display settings and local display identifiers. The app has no networking or telemetry code and does not record the screen. The remote-control app has its own permissions and privacy behavior. Review and redact diagnostic files before sharing them publicly.

## Implementation and limitations

The app uses Cocoa, public CoreGraphics display configuration calls, and the **private, undocumented `CGVirtualDisplay` family**. Required classes and selectors are checked before use. macOS updates may change this interface; successful compilation alone does not prove runtime compatibility.

This is an early beta, with a deliberately small scope. Sleep/wake, docking, external-display changes, and every type of forced process termination have not all been verified. If restoration is unsuccessful, use **System Settings → Displays** to select the normal desktop mode. The original records remain local.

The virtual-display approach is informed by [Chromium's macOS virtual display testing implementation](https://chromium.googlesource.com/chromium/src/+/HEAD/ui/display/mac/test/virtual_display_util_mac.mm). This project supplies its own minimal runtime bridge and app code. See [testing notes](docs/TESTING.md) and [release notes](CHANGELOG.md).

## Contributing

Issues are welcome. Useful reports include your Mac model, macOS version, mobile device model, UU Remote version, and whether the picture or pointer alignment was wrong. Do not include account credentials or unredacted local diagnostics.

## License

MIT. This independent project is not affiliated with or endorsed by Apple or NetEase. iPad, Mac, and UU Remote are their respective owners' product names.
