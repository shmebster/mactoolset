<p align="center">
  <img src="docs/images/app-icon.png" width="128" alt="Mac Toolbox">
</p>

<h1 align="center">Mac Toolbox</h1>

<p align="center">
  A native macOS menu bar toolset, inspired by Parallels Toolbox.<br>
  Swift 6 · SwiftUI · ScreenCaptureKit · zero dependencies
</p>

<p align="center">
  <a href="https://github.com/shmebster/mactoolset/releases/latest"><img src="https://img.shields.io/github/v/release/shmebster/mactoolset?include_prereleases" alt="Release"></a>
  <a href="https://github.com/shmebster/mactoolset/actions/workflows/ci.yml"><img src="https://github.com/shmebster/mactoolset/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-15%2B-blue" alt="macOS 15+">
</p>

<p align="center">
  <img src="docs/images/panel.png" width="340" alt="Mac Toolbox panel">
</p>

## Tools

| | Tool | What it does |
|---|---|---|
| ☕ | **Prevent Sleep** | Keeps your Mac (and optionally the display) awake for 15 min … 8 h, indefinitely, or a custom duration. |
| 🌙 | **Sleep Timer** | Puts the Mac to sleep, turns off the display, or shuts down after a set time. Extend a running timer by +5/15/30 min. |
| 🖥 | **Screen Recording** | Records the full screen or a selected area to HEVC `.mov`, with system audio, microphone, cursor and click highlighting. |
| 🪟 | **Window Recording** | Records a single window or a whole app (picked with the macOS system picker), with the same options. |
| 🎙 | **Audio Recording** | Records system audio, the microphone, or both (mixed into one track) to AAC `.m4a`. |

The UI is currently in Russian.

### Usage

- **The switch** on a card starts the tool with your *last* settings — the last duration, the last recording mode.
- **Click a card** to expand it and pick an exact duration, mode or source; picking one starts the tool right away and becomes the new default. The default option is outlined, the active one is filled.
- Only one screen or window recording runs at a time.
- **The menu bar icon** shows what's running: toolbox — nothing, cup — Prevent Sleep, moon — Sleep Timer, dot — recording. Next to it you see the time left (timers, in minutes) or the elapsed time (recordings). You can turn this off in settings ⚙︎.
- **Area recording:** drag across the screen; Esc or right-click cancels.
- **Window recording:** the macOS picker opens — click the window you want.
- **Stop a recording** with the card's switch or the system recording indicator in the menu bar. The finished file is revealed in Finder.

Recordings are saved to `~/Movies/Mac Toolbox` (video) and `~/Music/Mac Toolbox` (audio); both folders are one click away in the settings menu.

## Installation

1. Download `MacToolbox-*.dmg` from the [latest release](https://github.com/shmebster/mactoolset/releases/latest).
2. Open the DMG and drag **MacToolbox** to Applications.
3. The app is ad-hoc signed and not notarized, so macOS blocks it on first launch.
   Go to *System Settings → Privacy & Security* and click **Open Anyway**, or remove the quarantine flag:
   ```sh
   xattr -dr com.apple.quarantine /Applications/MacToolbox.app
   ```

The build is universal — it runs on both Apple Silicon and Intel Macs.

## Requirements

- macOS 15 Sequoia or later
- To build: Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Building from source

```sh
brew install xcodegen
git clone https://github.com/shmebster/mactoolset.git
cd mactoolset
make run
```

| Command | What it does |
|---|---|
| `make run` | generates the project, builds Debug and relaunches the app |
| `make build` | build only (output in `build/Build/Products/Debug/MacToolbox.app`) |
| `make project` | only generates `MacToolbox.xcodeproj` for working in Xcode |
| `make dmg VERSION=0.2.0` | universal Release build, DMG and ZIP in `dist/` (same as CI) |
| `make clean` | removes `build/`, `dist/` and the generated project |

`MacToolbox.xcodeproj` is not checked in — `project.yml` is the source of truth.

## Permissions

| Permission | Asked when | Why |
|---|---|---|
| Screen & System Audio Recording | first screen, window or audio recording | ScreenCaptureKit |
| Microphone | first recording with the microphone | microphone capture |
| Automation → System Events | first shutdown by Sleep Timer | `shut down` via AppleScript |

Prevent Sleep, plus Sleep and Display in Sleep Timer, need no permissions.

> [!NOTE]
> Builds are ad-hoc signed, so macOS may ask for screen recording access again after an update or
> rebuild. If access gets stuck, remove Mac Toolbox from *System Settings → Privacy & Security →
> Screen & System Audio Recording* and grant it again.

## Releasing

1. Move the changes into a `## 0.2.0 — <date>` section in `CHANGELOG.md`.
2. Commit and tag:
   ```sh
   git tag v0.2.0
   git push origin main v0.2.0
   ```
3. The [`Release`](.github/workflows/release.yml) workflow builds a universal app, packages a DMG and ZIP
   (with `SHA256SUMS.txt`) and publishes a GitHub Release. The release notes come from that version's
   section in `CHANGELOG.md` plus install instructions. Versions with a hyphen (`v0.3.0-beta.1`) are
   published as pre-releases.

You can run a test build without publishing via *Actions → Release → Run workflow*; the files are
attached to the run as artifacts.

[`CI`](.github/workflows/ci.yml) checks that the project builds on every push to `main` and every PR.

## Documentation

- [Architecture and adding a new tool](docs/ARCHITECTURE.md) (Russian)
- [Changelog](CHANGELOG.md) (Russian)
