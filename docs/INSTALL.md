# Install Hey Voice

**Current availability:** community preview for macOS 15+, available as a precompiled DMG or source code. The DMG is not notarized by Apple and may require first-launch approval. Windows is not supported by this build.

Created by [@StefanoGPT](https://x.com/StefanoGPT).

## The simple installation path

[Download the precompiled DMG](https://github.com/StefanoGPT/hey-voice/releases/download/v0.1.2/HeyVoice-0.1.2-macOS.dmg). No Terminal or developer tools are required. GitHub's automatic “Source code” ZIP is not an installer.

1. Download **HeyVoice-…-macOS.dmg** from Releases. One download covers both Apple silicon and Intel Macs; speech-model availability can vary by device.
2. Open the DMG and drag **Hey Voice** onto **Applications**.
3. Eject the DMG. Open **Hey Voice** from Applications.
4. If macOS cannot verify the developer and you trust the release, open **System Settings → Privacy & Security → Open Anyway**, then confirm Open. This approves this app only. See [Apple's instructions](https://support.apple.com/en-us/102445). Managed Macs may prevent this. If macOS reports malware or damaged software, stop and report the message.
5. Click the small **orb** in the menu bar near the clock. This app has no main window or Dock icon.

## First setup: do this once

1. Open Codex / ChatGPT and go to **Settings → Voice → Voice chat hotkey**. Set a shortcut if the field is empty.
2. Click the Hey Voice orb, click its **Voice shortcut** field, and press the same combination. The two apps must use the same shortcut. The example ⌘6 is not a required default.
3. Keep **Hey Voice** or change the word after “Hey” and click **Save** (or press Return). The caption confirms the saved phrase. While editing, the last saved word stays in use; Save does not switch paused detection on. Choose the recognition language under **Options** if needed.
4. Click **Enable Detection**. Allow **Microphone** and **Speech Recognition** when macOS asks.
5. If asked for **Accessibility**, open **System Settings → Privacy & Security → Accessibility** and enable **Hey Voice**. Return to the orb and click Enable again.
6. Say **“Hey Voice”**, wait for the Voice interface to open, then speak your request.

After closing a call, allow about two seconds for Codex to release the microphone and detection to restart. The popover shows a short countdown when it is waiting. **Options → Launch at login** starts the companion after signing in.

## If something does not work

- **Nothing happens when speaking:** click the orb, read any message, and press **Test**. If Test does not open Voice, check the matching shortcut and Accessibility permission first.
- **Works once, then misses:** close the existing Voice call and wait for the countdown. Pausing or muting a call may leave its microphone active.
- **Permission is enabled but still reported missing:** quit and reopen the installed app. If you previously moved or rebuilt a development copy, remove only the old Hey Voice Accessibility entry, add the copy in Applications, and enable it again.
- **Recognition language unavailable:** choose another language or enable/download that language in macOS Dictation settings. The companion does not fall back to cloud recognition.
- **Music or a browser is open:** these do not intentionally block detection. Audio quality can still affect recognition; a video saying the exact wake phrase may activate Voice.
- **Downloaded Source code ZIP:** that contains the project, not a runnable app. Use the DMG release instead.

Never disable Gatekeeper or remove quarantine attributes to install Hey Voice. Use only the app-specific approval described above. If that option is unavailable, report your macOS version and the exact message.

## Source build: available now

This option requires developer tools and is intended for people comfortable with Terminal. [Follow the build instructions](../README.md#build-from-source-developers). A local build does not prove the downloaded public installer has passed Apple's checks.

## Remove Hey Voice

Turn off **Options → Launch at login**, click **Quit**, and move Hey Voice from Applications to the Trash. Remove its Privacy & Security entries if desired. Details about local preferences and cached models are in [Privacy](../PRIVACY.md).

## Find your version

Open the Hey Voice menu-bar panel. The installed version appears at the bottom right; hover over it to see the build number. Include this version when reporting an issue.
