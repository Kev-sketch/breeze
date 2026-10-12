<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/readme/logo-dark.svg">
    <img src="docs/assets/readme/logo.svg" width="220" alt="Breeze logo">
  </picture>
</p>

<h1 align="center">Breeze</h1>

<p align="center">
  One menu bar icon doing the job of a dozen paid Mac apps.<br>
  Install only what you use.
</p>

<p align="center">
  <a href="https://github.com/Kev-sketch/breeze">Repository</a> ·
  <a href="#install">Install</a> ·
  <a href="#everything-it-does">Features</a> ·
  <a href="#private-by-default">Privacy</a> ·
  <a href="CHANGELOG.md">Changelog</a> ·
  <a href="https://github.com/Kev-sketch/breeze/issues">Issues</a>
</p>

<p align="center">
  <a href="https://github.com/Kev-sketch/breeze/releases"><img src="https://img.shields.io/github/v/release/Kev-sketch/breeze?label=release&color=4c8dff" alt="Latest release"></a>
  <a href="https://github.com/Kev-sketch/breeze/releases"><img src="https://img.shields.io/github/downloads/Kev-sketch/breeze/total?color=4c8dff" alt="Downloads"></a>
  <a href="https://github.com/Kev-sketch/breeze/actions/workflows/ci.yml"><img src="https://github.com/Kev-sketch/breeze/actions/workflows/ci.yml/badge.svg?branch=main&event=push" alt="CI status"></a>
  <a href="#what-you-need"><img src="https://img.shields.io/badge/macOS-13%2B%20Universal-black" alt="macOS 13 and newer, Intel and Apple Silicon"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue" alt="License GPL 3.0 or later"></a>
</p>

<p align="center">
  <em>Unofficial fork of the GPL-3.0 <a href="https://github.com/vorssaint/vorssaint-utils">Vorssaint</a>
  project, rebuilt as a universal binary (Intel + Apple Silicon) for macOS 13+.</em>
</p>

<p align="center">
  <img src="docs/assets/readme/panel-mixer.png" width="196" alt="Volume mixer with per app sliders, one app boosted past 100 percent">
  <img src="docs/assets/readme/panel-system.png" width="196" alt="System tab with temperatures, usage graphs and memory pressure">
  <img src="docs/assets/readme/panel-controls.png" width="196" alt="Window controls with the app switcher and Dock features">
  <img src="docs/assets/readme/panel-utilities.png" width="196" alt="Utilities with cleaner, Homebrew, media tools and clipboard">
<img src="docs/assets/readme/panel-breeze.png" width="196" alt="The full Breeze menu-bar panel, showing the controls and utilities tabs side by side">
</p>

Per app volume, a real system monitor, a better app switcher, window snapping, Dock previews, clipboard history, text snippets, a file shelf, an uninstaller. The utilities Mac users usually buy one by one, together behind a single menu bar icon, with no account, no telemetry and no subscription.

## Install only what you use

Choose individual features or start with a preset. Uninstalled features stop loading and disappear from the interface; reinstalling restores their settings. Setup asks only for the permissions your choices need.

<p align="center">
  <img src="docs/assets/readme/features-hub.png" width="720" alt="The Features hub in Settings, installing and uninstalling whole features">
</p>

Reorder or hide panel sections, choose a compact layout, and export settings to another Mac. The app supports more than a dozen languages.

## Everything it does

### Sound

- **Volume mixer.** Set volume per app, boost quiet audio past 100%, and pin or reorder favorites. No audio driver required.
- **Per app output.** Play music through speakers while a call uses your headset.
- **Output switcher.** Switch audio outputs with a shortcut and lower the volume when headphones disconnect.
- **Microphone tools.** Choose a preferred input, adjust its level on supported devices, and mute all microphones with one shortcut.
- **Music app blocker.** Prevent unwanted Music launches after detected playback-button presses. Requires Accessibility.

### Know what your Mac is doing

- **System monitor.** CPU, GPU, memory, temperatures, battery health and power use, with history graphs and a view of energy-hungry apps.
- **Fan Control (beta).** Set manual fan speeds or temperature curves and monitor live RPM.
- **Menu bar readouts.** Put your chosen readings, usage bars, battery time or fan speed directly in the menu bar.
- **Network.** See live traffic, session totals and your local IP address, or run a speed test.
- **Alerts.** Get notified about sustained CPU load, high temperatures, memory pressure, low disk space or low battery.

### Windows and the Dock

- **App switcher.** Switch between apps and windows with live previews, search and display filters. A simpler mode works without screen capture.
- **Window layout.** Snap windows into layouts, move them between displays and restore earlier positions using shortcuts, screen edges or modifier-drag gestures.
- **Dock Preview.** Hover over Dock icons to preview windows across desktops. Switch, close, move or snap them from the preview.
- **Dock clicks.** Click an active app's Dock icon to minimize, hide or cycle through its windows.
- **Maximize windows.** Use the green button to fill the screen without creating another Space.
- **Fixed Space order.** Keep Spaces in the order you set instead of rearranging them by recent use. Turning it off restores your previous setting.
- **Quit on close.** Quit selected apps when their last window closes.
- **Quit and close protection.** Prevent accidental ⌘Q or ⌘W with a hold, double press or extra modifier, per app.

<p align="center">
  <img src="docs/assets/readme/quit-protection-hold.png" width="300" alt="The hold-to-confirm prompt showing progress below the Command-Q quit shortcut hint">
</p>

<p align="center">
  <img src="docs/assets/readme/window-switcher.gif" width="540" alt="The window switcher showing live thumbnails of open windows">
</p>

### Keyboard and mouse

- **Text snippets.** Expand short triggers into text with clipboard, date and time variables, or insert snippets from a searchable menu.
- **Smooth scrolling.** Give your mouse wheel a fluid glide with adjustable speed and response.
- **Pointer acceleration.** Disable mouse acceleration and restore your previous setting when turned off.
- **Linear scrolling.** Make every mouse wheel notch scroll the same number of lines, however fast the wheel spins.
- **Focus follows mouse.** Bring the window under the pointer forward after an adjustable pause.
- **Scroll direction.** Invert vertical and horizontal mouse scrolling independently of the trackpad.
- **Scroll sideways while holding a key.** Turn vertical wheel movement into horizontal scrolling while holding a chosen key.
- **Side buttons.** Use mouse Back and Forward buttons in Finder, browsers and compatible apps.
- **Mouse button shortcuts.** Assign keys to extra buttons and side wheels, or use button-drag gestures for Spaces and Mission Control.
- **Middle click.** Turn a three-finger trackpad press into a middle click.
- **Apps to leave alone.** Exclude chosen apps from mouse enhancements.
- **Extra click filter.** Ignore accidental rapid clicks from worn mouse buttons without delaying normal clicks.
- **Key debounce.** Filter repeated letters caused by a worn keyboard.
- **Super key.** Use Caps Lock or a right-side modifier as a shortcut combination, with a separate tap action and app exclusions.
- **Keyboard shortcuts.** Manage feature shortcuts in one place, including optional takeover of supported macOS shortcuts while a feature is active.

### Clipboard, files and links

- **Clipboard history.** Search local text, image and file history, pin favorites, preview entries and paste with shortcuts.
- **Auto clear clipboard.** Clear the system clipboard after a delay, sleep or lock, while keeping saved history.
- **Paste as plain text.** Paste without formatting while preserving the original clipboard content.
- **Shelf.** Park files, text and links near your cursor while dragging, then drop or share them later.
- **Finder shortcuts.** Move files with ⌘X and ⌘V, rename with F2, or paste copied images as PNG files.
- **Clean URL.** Remove tracking parameters from links, manually or automatically.
- **Disk image installer.** Install an app from a mounted disk image and eject it, with optional download cleanup.

### Everyday tools

- **Dynamic Island.** Keep music, notifications, calendars, timers, downloads and everyday controls around the camera cutout, or a simulated one on other Macs. Customize sections and shortcuts, with optional lyrics, a live equalizer, camera preview and file tools.
- **AI agents.** Follow Claude, Codex, OpenCode and GitHub Copilot in the Dynamic Island: plan limits and when they reset where available, tokens, API value, models, projects and live work, with a notice when a long task finishes. Codex's banked resets can be used from there too. Copilot uses local CLI/app session logs; its token totals update when shutdown metrics arrive, and aggregate API-value estimates use base rates.
- **Command Bar.** Search apps, windows, files, clipboard history, snippets and app menu commands from one field. Calculate, convert units, find emoji or run saved scripts.
- **Quick panel.** Open a floating palette of favorite tools with ⌃⌘V.
- **Quick toggles.** Switch appearance, hide desktop icons, eject disks, empty the Trash, lock the screen and more.
- **Radial menu.** Open a customizable wheel of apps, files, shortcuts and tools around the pointer, with profiles and submenus.
- **Scratchpad.** Keep autosaved notes in tabs, with Markdown preview and export, in a floating window or Dynamic Island.
- **Cleaning Mode.** Lock keyboard input while cleaning, with a black screen or a small visible indicator.

### Capture and create

- **Screen capture.** Switch between screenshots, recording, text recognition and color picking in one selector with a pixel magnifier.
- **Screenshot.** Capture an area, window, screen or scrolling page. Annotate, crop, redact, add backgrounds and watermarks, pin captures, send them through the Share menu or share an expiring link.
- **Screen recording.** Record with separate system-audio and microphone tracks. Trim, cut, add automatic zooms, blur private details and export video or GIFs, or share an expiring link.
- **Camera preview.** Check your camera in a floating mirror or Dynamic Island before a call.
- **Copy text from screen.** Recognize text offline from any screen area, or read a QR code.
- **Color picker.** Copy a screen color as HEX, RGB, HSL or SwiftUI code.
- **Media tools.** Compress and edit videos, batch-convert images, add watermarks, make GIFs and extract text, all locally.

### App management

- **App updates.** Check store apps, package-managed apps and supported developer feeds in one list. Install managed updates together or open an app's own updater.
- **Cleaner.** Remove caches, logs and app leftovers, manually or on a schedule.
- **Messaging downloads.** Review, organize or move messaging downloads to the Trash using retention rules.
- **Uninstaller.** Remove apps and review their related caches, preferences and helpers before moving them to the Trash.
- **Homebrew manager.** Search, install and remove formulae and casks without opening a terminal.
- **Port manager.** Find processes listening on network ports and stop them with Kill Process when installed.

### Energy and display

- **Keep awake.** Keep your Mac working on a timer, with the lid closed, or while selected apps, power or external displays are present.
- **Displays.** Control individual displays and brightness, with hardware control where supported, half or quarter steps for the brightness keys, optional extra dimming below a monitor's minimum, and software dimming as a fallback.
- **Extra brightness.** Use a MacBook Pro XDR display's HDR headroom to go beyond its normal maximum brightness.
- **Bluetooth on sleep.** Disconnect Bluetooth during sleep and restore it on wake only if Breeze turned it off.

## Install

Download the disk image from the [releases page](https://github.com/Kev-sketch/breeze/releases),
open it, and drag **Breeze** into Applications.

> **Unofficial fork build.** It is **ad-hoc signed**, not notarized, so macOS shows a Gatekeeper
> warning on first launch — right-click the app and choose **Open** (or run
> `xattr -dr com.apple.quarantine /Applications/Breeze.app`). Requires **macOS 13 Ventura or newer**.

## Uninstall

Quit Breeze, then drag **Breeze** from Applications to the Trash.

To remove Breeze completely, including its settings and permissions:

```sh
./Tools/uninstall.sh
```

## Private by default

Breeze is local-first, with no account, analytics or tracking. The network is touched only by things you can see: update checks, the speed test, Homebrew actions, optional online lyric lookup, temporary screenshot or recording links and feedback you explicitly send. The full story is in the [privacy notes](docs/PRIVACY.md).

Permissions get the same treatment. Every one is optional, the app explains each in plain words, shows which features actually use it, and even tells you when a permission you granted is no longer needed by anything, with a shortcut to revoke it.

<p align="center">
  <img src="docs/assets/readme/permissions.png" width="720" alt="The Permissions page showing what each permission does, which features use it, and an unused permission warning">
</p>

See the [permissions guide](docs/PERMISSIONS.md) for which features need access and what remains available without it.

## What you need

- Any Mac — Apple Silicon **or** Intel
- macOS 13 Ventura or newer

> **Legacy-OS port note.** This branch builds a **universal binary (Intel + Apple Silicon)** with a
> minimum of **macOS 13 (Ventura)** — the macOS-14 APIs used across the codebase are covered by
> Ventura fallbacks (see [`PORTING-macos-legacy.md`](PORTING-macos-legacy.md)). It does **not** reach
> macOS 10.0–10.14 — a SwiftUI app cannot run there (SwiftUI needs 10.15; Swift needs 10.10; 10.0–10.3
> are PowerPC-only).

### Build it yourself

```sh
git clone https://github.com/Kev-sketch/breeze.git
cd breeze-utils
./build.sh --dev            # build the separate Developer variant
./build.sh --dev --install  # install and launch it
```

Xcode Command Line Tools are the only requirement. The [contributing guide](CONTRIBUTING.md) covers the layout and conventions. Official builds come only from the maintainer: the GPL covers the source, while the Breeze name, icon and look are covered by [TRADEMARKS.md](TRADEMARKS.md), so forks need their own identity.

## When something misbehaves

See [troubleshooting](docs/TROUBLESHOOTING.md) for launch problems, permissions and missing previews, or [support](SUPPORT.md) for help.

## Documentation

- [Privacy](docs/PRIVACY.md), what does and does not leave your Mac
- [Permissions](docs/PERMISSIONS.md), every macOS permission in plain words
- [Troubleshooting](docs/TROUBLESHOOTING.md), the common fixes
- [Contributing](CONTRIBUTING.md), build, layout and conventions
- [Support](SUPPORT.md), where to get help
- [Security](SECURITY.md), how to report a vulnerability

## Community

This repository is a personal fork. The original project, its design and the vast majority of the code come from upstream [Vorssaint](https://github.com/vorssaint/vorssaint-utils); please direct general bug reports and feature requests there. Fork-specific changes are documented in [PORTING-macos-legacy.md](PORTING-macos-legacy.md).

## Acknowledgements

- Original project: [Vorssaint](https://github.com/vorssaint/vorssaint-utils) (© 2026 Vorssaint)
- Original app icon designed by [@divisionseven](https://github.com/divisionseven)

## License

[GPL 3.0 or later](LICENSE). Source copyright © 2026 Vorssaint; fork modifications © 2026 Kev-sketch. The license covers the source code; the original Vorssaint name, logo and look are covered separately in [TRADEMARKS.md](TRADEMARKS.md).

<p align="center">
  <sub>Fork by <a href="https://github.com/Kev-sketch">@Kev-sketch</a> · based on <a href="https://github.com/vorssaint/vorssaint-utils">Vorssaint</a></sub>
</p>