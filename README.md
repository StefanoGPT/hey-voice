# Hey Voice

<img src="Resources/VoiceOrb.png" width="112" height="112" alt="Hey Voice luminous orb icon">

[![Build and test](https://github.com/StefanoGPT/hey-voice/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanoGPT/hey-voice/actions/workflows/ci.yml)

**Say “Hey Voice.” Codex Voice opens. You take it from there.**

A tiny, independent macOS menu-bar companion that connects a customizable wake phrase to your desktop app’s voice hotkey. Change **Voice** to **Chat**, **Atlas**, or another word. The prefix stays **Hey**.

**Created by [@StefanoGPT](https://x.com/StefanoGPT).** [Credits](CREDITS.md)

**Status: macOS community preview, 0.1.1.** Available as a precompiled DMG or source code. Real spoken activation and re-arming have been confirmed on one Mac, with 18 automated policy tests. The precompiled app is ad-hoc signed and **not notarized by Apple**; first launch may require your approval in macOS Privacy & Security. See [validation](docs/VALIDATION.md) for coverage. Not affiliated with or endorsed by OpenAI.

**Windows:** planned, not implemented. This Swift/AppKit app runs on macOS only. See the [Windows roadmap](docs/WINDOWS.md).

## What it does

- Detects “Hey” + your chosen word using Apple’s on-device speech recognition.
- Prepares a local language model from your chosen phrase to help recognition prefer it. First setup may take a moment; the popover shows a preparation message.
- Sends a configurable keyboard shortcut to start the existing Codex / ChatGPT Voice experience.
- Stops its microphone capture before sending the shortcut.
- Keeps working while other apps play audio or use their microphone. Pauses while Codex itself uses the microphone, then re-arms after the call.
- Lives entirely in a compact menu-bar popover with Pause / Enable, a shortcut recorder, and optional launch at login. No standalone settings window or app chooser.
- Adds **no activation sound, listening animation, audio meter, or floating overlay**.
- Requires no account or API key for the companion. Codex Voice still requires its own access and allowance.

macOS displays its own microphone privacy indicator while capture is active. Hey Voice does not hide or replace it.

## Requirements

- macOS 15 or later.
- An available Apple on-device speech recognition model for the selected language. If unavailable, detection stops with an explanation; cloud recognition is never used as a fallback.
- Codex / ChatGPT desktop with a configured **Voice chat hotkey**.
- Microphone, Speech Recognition, and Accessibility permissions for Hey Voice.
- Xcode 16 or newer to build from source. No third-party package dependencies.

The build script supports Apple silicon and Intel. An Intel build is not evidence of on-device model availability on every Intel Mac.

## Install the precompiled app

**[Download Hey Voice for macOS (.dmg)](https://github.com/StefanoGPT/hey-voice/releases/download/v0.1.1/HeyVoice-0.1.1-macOS.dmg)** · [Release notes and checksums](https://github.com/StefanoGPT/hey-voice/releases/tag/v0.1.1)

1. Open the DMG and drag **Hey Voice** onto **Applications**.
2. Eject the DMG, then open Hey Voice from Applications.
3. This community build is not notarized. If macOS cannot verify the developer, and you trust this release, use **System Settings → Privacy & Security → Open Anyway**, then confirm Open. This creates an exception for this app only. [Apple's instructions](https://support.apple.com/en-us/102445).
4. Click the orb in the menu bar, match your Codex Voice shortcut, and enable detection. Allow Microphone, Speech Recognition, and Accessibility when asked.

**No Terminal, Xcode, Apple Developer account, or API key is needed to use the precompiled app.** It requires macOS 15+ and an available on-device recognition language. Managed Macs may not allow opening unnotarized software. If macOS reports malware or damaged software, stop and report the message; do not disable security protections.

[Simple setup and troubleshooting guide](docs/INSTALL.md). Prefer to build it yourself? Follow the separate developer instructions below. GitHub's automatic “Source code” ZIP contains the project, not a runnable app.

## Build from source (developers)

```sh
git clone https://github.com/StefanoGPT/hey-voice.git
cd hey-voice
swift test
./scripts/build-app.sh
open 'dist/Hey Voice.app'
```

The build is ad-hoc signed by default for local development. For stable permissions across rebuilds, use your own development signing identity:

```sh
SIGNING_IDENTITY='Apple Development: Your Name (TEAMID)' ./scripts/build-app.sh
```

Open the `.app` bundle rather than using `swift run`: macOS needs the bundle’s usage descriptions for permission prompts. Quit the previous copy before rebuilding. Move your chosen build into Applications before granting permissions or enabling launch at login. Replacing or moving an ad-hoc signed build may require re-granting permissions.

## Set up

1. In Codex, configure **Settings → Voice → Voice chat hotkey**. Choose a global shortcut that does not conflict with your other apps.
2. Open Hey Voice. The default phrase is **Hey Voice** and the example hotkey is **⌘6**. ⌘6 is a starting value, not a documented Codex default.
3. Click the **orb** icon in the menu bar. Hey Voice automatically locates Codex by its application identity, including installations named `ChatGPT.app`. It only targets Codex / ChatGPT.
4. The popover shows the exact path: **Codex → Settings → Voice → Voice chat hotkey**. **Open Codex Settings** opens Settings; choose Voice there. Click the shortcut field and press the matching shortcut. A temporary macOS event tap isolates the combination from global hotkeys during recording. Include Command, Control, or Option. Escape cancels recording; capture also ends on focus loss or after 20 seconds. Accessibility permission is needed for isolated recording.
5. Set the word after **Hey**, then click **Enable Detection** and grant the requested permissions. If macOS opens Accessibility settings, return and click Enable after granting access.
6. Say **“Hey Voice”** (or your custom phrase). Wait for Codex’s Voice UI to connect, then give your request.

The companion opens Voice; it does not capture or forward the instruction you say next. Continuous “Hey Voice, do this…” is not supported by the hotkey bridge. Voice readiness and ending the call belong to Codex. The companion does not assume the shortcut toggles or closes a call.

## Preventing repeated and self-triggered activation

The app reads CoreAudio process activity flags and recognizes Codex processes by app identity, executable location, and a bounded parent-process lookup. It does **not** capture system output audio. It releases its microphone while Codex or a Codex voice helper has an active input stream and waits 1.5 seconds after observing that stream end. An 8-second startup guard prevents repeated shortcuts while Voice opens; once Codex takes the microphone, the call's activity replaces that guard. A short call therefore does not leave the companion waiting for the rest of an arbitrary 8-second timer. If no Codex input stream is observed, the full startup guard remains. The popover shows remaining wait time. The app checks activity again immediately before the keystroke and discards callbacks from stopped speech sessions.

**Chrome, music, videos, and microphone use by unrelated apps do not block activation.** You do not need to find or close silent browser audio streams. If the required activity information cannot be read, detection waits and shows a message. Muting an existing Codex call may keep its microphone stream active; finish the call to re-arm the companion.

This is not acoustic echo cancellation or speaker authentication. Background media that clearly says your exact wake phrase may activate Voice. The active-call guard reduces Codex re-triggering itself during a call; it cannot guarantee rejection of arbitrary media played by other apps. Choose a distinctive word, use headphones when helpful, and pause detection when you do not want it.

Detection suspends on display sleep, system sleep, and inactive desktop sessions. Long recognition requests rotate after 50 seconds; recovery can introduce brief listening gaps. Device-configuration changes restart recognition with bounded retries. Repeated failures pause detection with an explanation. This implementation uses speech recognition rather than a specialized low-power keyword model; idle energy use still needs measurement on representative hardware.

The matcher rejects wake phrases embedded in an already recognized sentence. A partial result can still match before later words arrive.

## Privacy

Hey Voice has no analytics, network client, transcript log, audio file storage, or credential storage. Audio buffers and transcription segments exist in memory only for the current recognition session. Preferences (word, language, shortcut, and enable state) are saved locally. See [PRIVACY.md](PRIVACY.md).

The implementation checks `supportsOnDeviceRecognition` and sets `requiresOnDeviceRecognition = true`. Apple controls language model availability and downloads. Speech authorization may use Apple’s generic permission wording; the app never requests server recognition. Codex’s handling of the subsequent voice conversation is separate.

## Development and release

```sh
swift test
UNIVERSAL=1 ./scripts/build-app.sh
'dist/Hey Voice.app/Contents/MacOS/HeyVoice' --self-check
```

`--self-check` reads recognition availability, audio activity flags, Accessibility trust, and target availability. It does not open a microphone or send a shortcut. It is a diagnostic, not an end-to-end voice test.

Two packaging paths are available:

- **Community preview (current):** `VERSION=0.1.1 scripts/package-preview.sh` builds a universal DMG, app ZIP, and SHA-256 checksums using ad-hoc signing. It never uses a personal certificate or Apple account. The manually triggered **Package community preview** GitHub workflow builds these files without Apple secrets. The first-launch notice must remain visible in release notes and the setup guide.
- **Optional notarized distribution:** `scripts/package-release.sh` retains a separate Developer ID + notarization path for a future maintainer who chooses it. This is not required for the current OSS release and is not used by the community workflow. See [release documentation](docs/RELEASING.md).

Neither script publishes automatically. Downloadable previews should be attached to a GitHub prerelease with their checksums and the exact source commit. Follow the [release checklist](docs/RELEASING.md); never describe an ad-hoc build as Apple-verified or notarized.

Shortcut interception is temporary, foreground-only, and stores only the selected key code/modifiers. No keystroke history is recorded. It is removed on completion, cancellation, focus loss, or timeout.

Pull requests run build and policy checks without signing secrets. The separate manual packaging workflow exports community preview artifacts for release review.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). MIT licensed. Useful contributions include microphone/device recovery, energy measurements, recognition quality across accents, and reproducible reports against specific Codex versions.

## API references

- [Apple: on-device recognition availability](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)
- [Apple: require on-device recognition](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)
- [Apple: customize on-device recognition](https://developer.apple.com/documentation/speech/sfcustomlanguagemodeldata)
- [Apple: per-process input activity](https://developer.apple.com/documentation/coreaudio/kaudioprocesspropertyisrunninginput)
- [Apple: per-process output activity](https://developer.apple.com/documentation/coreaudio/kaudioprocesspropertyisrunningoutput)
- [OpenAI: Voice and its configurable hotkey](https://learn.chatgpt.com/docs/features/voice)
