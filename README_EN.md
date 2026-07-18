<div align="center">
  <img src="Assets/MenuVeil.png" width="128" alt="MenuVeil icon">
  <h1>MenuVeil</h1>
  <p>Manage menu bar icons hidden by the MacBook notch or limited screen space.</p>
  <p><a href="README.md">简体中文</a> · <strong>English</strong></p>
</div>

MenuVeil is a native macOS menu bar utility. It discovers menu bar items in the current session—including items pushed off-screen by the notch or limited space—and keeps less frequently used icons in an expandable hidden section.

## Features

- Discover all menu bar items in the current session, not only the ones still visible on screen.
- Manage icons in separate **Visible** and **Hidden** tabs.
- View and restore hidden icons from the MenuVeil menu bar popover.
- Save visibility preferences and reuse the previous layout immediately after relaunching.
- Keep newly discovered, unconfigured icons visible by default.
- Stay in the menu bar without occupying the Dock after the settings window is closed.
- Run entirely on-device with no network service required.

## Screenshots

<table>
  <tr>
    <td width="50%" align="center"><img src="images/3.png" alt="Visible menu bar items"><br><strong>Visible</strong>: review current items and choose what to hide</td>
    <td width="50%" align="center"><img src="images/4.png" alt="Hidden menu bar items"><br><strong>Hidden</strong>: review hidden items and restore them</td>
  </tr>
  <tr>
    <td width="50%" align="center"><img src="images/1.png" alt="MenuVeil menu bar control"><br>A compact menu bar control when everything is tucked away</td>
    <td width="50%" align="center"><img src="images/2.png" alt="Hidden items popover"><br>Restore an icon quickly without opening the settings window</td>
  </tr>
</table>

## Requirements

- macOS 14 Sonoma or later.
- Accessibility permission, used to move menu bar items.

## Installation

1. Download `MenuVeil-<version>.dmg` from Releases.
2. Open the DMG and drag MenuVeil into the Applications folder.
3. If macOS blocks the first launch, open **System Settings → Privacy & Security**, find MenuVeil, and click **Open Anyway**.
4. Follow the in-app prompt to enable MenuVeil under **System Settings → Privacy & Security → Accessibility**, then relaunch it.

Current release builds use ad-hoc signing because the project does not yet use an Apple Developer ID. This does not bypass macOS security checks; users must explicitly approve the first launch.

## Usage

1. Open MenuVeil and click **Hide** for an item in the **Visible** tab.
2. Click the double-chevron icon in the menu bar to view all hidden items.
3. Click **Show** in the popover to restore an item to the menu bar.
4. Use the **Settings** and **Quit** buttons at the bottom of the popover when needed.

MenuVeil remembers the layout. Future launches reuse the previous result directly, while icons from newly installed or newly discovered apps remain visible by default.

> macOS does not allow some system-managed items to be moved. MenuVeil disables controls for the items it can identify as fixed to prevent ineffective actions.

## Build from Source

Xcode 16 or another Swift 6-compatible development environment is required.

```bash
git clone <your-repository-url>
cd menu-veil
swift test
chmod +x scripts/build-app.sh scripts/build-dmg.sh
scripts/build-app.sh
open "dist/MenuVeil.app"
```

You can also open `Package.swift` in Xcode and run the `BarEverything` scheme. `BarEverything` is the current internal build target name; the resulting app is still named MenuVeil.

## Create a DMG

Without a Developer ID, run:

```bash
scripts/build-dmg.sh
```

The output is written to `dist/MenuVeil-0.1.0.dmg`. Override the version when needed:

```bash
MENUVEIL_VERSION=0.2.0 scripts/build-dmg.sh
```

Once you have an Apple Developer Program certificate and notarization credentials, create a signed and notarized build with:

```bash
MENUVEIL_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
MENUVEIL_NOTARY_PROFILE="MenuVeilNotary" \
scripts/build-dmg.sh
```

## Privacy

MenuVeil uses macOS Accessibility and window information APIs to identify and move menu bar items. Preferences are stored locally in `UserDefaults`. The app does not upload menu bar information or make network requests.

## Contributing

Issues and pull requests are welcome. When reporting a problem, please include the macOS version, MenuVeil version, the app that owns the affected icon, and clear reproduction steps.
