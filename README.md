# Hex for iPhone

[![iOS Build](https://github.com/Luraxx/hex-iphone/actions/workflows/build.yml/badge.svg)](https://github.com/Luraxx/hex-iphone/actions/workflows/build.yml)

Dictation like [Hex on the Mac](https://github.com/kitlangton/Hex) — but on the iPhone:
**press the Action Button → speak → press again → text.**
Transcription runs fully on-device using the same models as Hex on macOS
(**Parakeet TDT v2/v3** via [FluidAudio](https://github.com/FluidInference/FluidAudio), CoreML / Neural Engine). No cloud, no account, no audio ever leaves the phone.

## How it works

1. **Press the Action Button** (from anywhere — home screen, any app, lock screen): recording starts in the background and the **Dynamic Island** shows a timer plus Done/Discard buttons.
2. Press again (or tap "Done" in the Dynamic Island): Hex transcribes locally (v3 is multilingual, 25 languages).
3. The text is **copied to the clipboard** and queued for the **Hex keyboard**: if it is active in the current text field (or gets opened), it **auto-inserts** the text.

> **Honest platform limitation:** iOS does not let apps type text into other apps system-wide or intercept a held-down key globally like macOS does. The Action Button also delivers no "release" event — hence toggle (press/press) instead of hold. Action Button + Dynamic Island + auto-inserting keyboard is as close to the Mac experience as iOS allows (the same pattern used by superwhisper and friends).

## Requirements

- iPhone with an Action Button (15 Pro or newer) for the full experience — otherwise use Back Tap or the in-app button
- iOS 18+
- A Mac with Xcode to build and sideload (free Apple ID is enough)

## Installation

1. Install Xcode (Mac App Store, free) and launch it once so the iOS components get installed.
2. Clone this repo and open `Hex.xcodeproj`.
3. In Xcode: select the "Hex" project → for **all three targets** (Hex, HexWidgets, HexKeyboard) pick your **team** under *Signing & Capabilities* ("Automatically manage signing" on).
   - If the bundle IDs collide, change the `io.github.luraxx` prefix in `project.yml` and run `xcodegen generate`.
   - If Xcode cannot register the **App Group** `group.io.github.luraxx.hex`, pick your own name — in both `.entitlements` files **and** in `HexShared/Sources/HexShared/SharedConstants.swift`.
4. Connect your iPhone, select it as the destination, **▶ Run**.
5. On the iPhone: *Settings → General → VPN & Device Management* → trust your developer certificate.

> With a free Apple ID the signature lasts 7 days (just re-run from Xcode); with a paid developer account, 1 year.
> No Xcode at hand? CI produces an unsigned IPA artifact on every push ([Actions](../../actions)) that can be signed and installed with AltStore/SideStore.

## Setup on the iPhone

The app walks you through everything on first launch. Short version:

| Step | Where |
|---|---|
| Allow microphone | on first launch in the app |
| Download a model (~650 MB, Wi-Fi) | app → Settings → Transcription model (default: **Parakeet TDT v3**, multilingual) |
| Assign the Action Button | iOS Settings → **Action Button** → "Shortcut" → Hex **"Diktat"** |
| Enable the Hex keyboard | iOS Settings → General → Keyboard → Keyboards → add **Hex Tastatur** → **Allow Full Access** |

Full Access is only needed so the keyboard can read the shared App Group container (app ↔ keyboard hand-off). The keyboard contains no networking code whatsoever.

No Action Button? Map Back Tap (*Accessibility → Touch → Back Tap*) to the "Diktat" shortcut, or use the record button inside the app.

## Features

- Parakeet TDT **v2** (English) and **v3** (25 languages) with model management and download progress, like Hex on the Mac
- Recording starts **without opening the app** via `AudioRecordingIntent` (iOS 18) + Live Activity
- Dynamic Island: timer, Done/Discard, status, result preview
- Auto-copy + auto-insert (Hex keyboard), searchable history, "ignore under 0.3 s", max-duration safety net, system recording sounds + haptics
- Everything on-device; recording files are deleted right after transcription

> **Note:** the app UI is currently German-first. All strings live directly in the source and are easy to adapt; English localization is on the roadmap.

## Architecture

```
Hex/            App: SwiftUI UI, AppModel (state machine), AVAudioEngine recorder (16 kHz mono),
                ParakeetEngine (FluidAudio 0.15.5, same API usage as Hex/macOS),
                Live Activity controller, ToggleDictationIntent (AudioRecordingIntent, Action Button)
HexWidgets/     Live Activity (Dynamic Island + lock screen)
HexKeyboard/    Keyboard extension: inserts transcripts (Darwin notification + App Group)
HexShared/      Shared package: TranscriptStore, settings, constants
Shared/         Files compiled into BOTH app and widget target (attributes, LA intents)
project.yml     XcodeGen definition (the generated project is checked in as well)
```

## Roadmap ideas

- Control Center / lock screen control (iOS 18 ControlWidget)
- Transforms (replacement rules) like on the Mac
- English localization of the UI
- Whisper models as an alternative engine (WhisperKit)

## Credits

- [Hex](https://github.com/kitlangton/Hex) by Kit Langton — the original, and the reference for the Parakeet integration
- [FluidAudio](https://github.com/FluidInference/FluidAudio) — Parakeet CoreML runtime

## License

[MIT](LICENSE)
