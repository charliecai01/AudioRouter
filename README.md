# AudioRouter

A macOS menu bar app that routes each application's audio to a different
output device — Chrome to your speakers, Spotify to your headphones, at the
same time. Free, open source, and doesn't send anything home.

![AudioRouter menu bar panel](docs/screenshot.png)

There's no prebuilt download yet. See [Building from source](#building-from-source).

## Why

Tools like SoundSource solve this well but are paid, and the free tier nags
you with noise every 30 minutes. AudioRouter does the one thing — per-app
output routing — for free, using Apple's own public APIs.

## Features

- **Per-app output routing** — assign any app to any connected output device.
- **Independent volume + live level meter per app.**
- **Output device controls** — pick the default output, and set or mute each
  device's volume from the same menu.
- **Lives in the menu bar** — no Dock icon, no extra windows.
- **No telemetry, no accounts, no network access.**

## How it works

AudioRouter uses Core Audio's **Process Tap API**
(`AudioHardwareCreateProcessTap`, macOS 14.4+) to capture a specific
process's audio, then plays it back on the output device you choose through
a private Aggregate Device + IOProc passthrough. No kernel extensions, no
virtual audio drivers — just the same public API Apple introduced for this
in Sonoma 14.4.

Process Taps don't currently work reliably inside the App Sandbox, so
AudioRouter can't go on the Mac App Store. `release.sh` signs release builds
with a Developer ID and notarizes them instead (see [Releasing](#releasing)),
the same way Loopback and SoundSource are distributed.

## Requirements

- macOS 14.4 or later
- Apple Silicon or Intel

## Building from source

```bash
git clone https://github.com/charliecai01/AudioRouter.git
cd AudioRouter
brew install xcodegen
xcodegen generate
open AudioRouter.xcodeproj
```

Then hit Run (⌘R) in Xcode. `project.yml` is the source of truth for the
Xcode project (via [XcodeGen](https://github.com/yonaskolb/XcodeGen)) — the
`.xcodeproj` itself isn't committed.

### First run: audio capture permission

The first time you route an app's audio, macOS will ask you to grant
"Screen & System Audio Recording" permission (System Settings → Privacy &
Security). This is a real system permission dialog, not something the app
can skip — it's what makes the audio capture possible at all.

### Releasing

`./release.sh` archives, signs, notarizes, staples, and packages a `.dmg`. It expects a Developer ID Application
certificate and a stored `notarytool` credentials profile — see the comments
at the top of the script.

## Contributing

Issues and pull requests are welcome. This is a side project built to scratch
a personal itch, so response times may vary, but feedback is genuinely
wanted — especially bug reports with your macOS version and the devices
involved.

## License

[MIT](LICENSE)
