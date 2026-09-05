# Privacy

Hey Voice processes microphone audio through Apple’s on-device Speech framework solely to recognize a wake phrase. The request is not started unless on-device recognition is supported, and every request requires on-device processing.

The app has no network client, analytics SDK, ad SDK, crash uploader, or external dependencies. It does not write audio, recognized speech, or transcripts to disk. Buffers and recognition segments are held temporarily in memory. CoreAudio queries read audio activity flags; a bounded process identity/parent lookup identifies Codex microphone use. No system audio samples are captured. Unrelated playback and microphone use do not suspend detection.

When you explicitly click the shortcut recorder, a temporary foreground event tap captures the chosen key code and modifiers before global shortcuts receive them. It is removed when recording finishes, is cancelled, loses focus, or times out after 20 seconds. It does not store a keystroke history or remain active during normal wake detection.

Local preferences contain the selected keyword and language, shortcut key code/modifiers, and detection/onboarding choices. macOS manages permissions and login-item registration. No API keys or login credentials are requested or stored by the companion.

To improve recognition, the app prepares an Apple custom language model from the configured wake phrase as text. The generated training data and model are stored under the app's macOS cache directory and reused across listening sessions. They contain no microphone-derived training examples or voice recordings. Removing `~/Library/Caches/io.github.heyvoice.companion` removes this app-managed model cache.

An optional developer launch flag, `--diagnostics <path>`, writes a local JSON file with microphone level, session timing, recognition word counts, predefined wake-prefix categories, phrase-match flags, and shortcut dispatch events. It includes neither audio nor transcript text. Diagnostics are disabled on ordinary launches; no file is uploaded. Delete the supplied file to remove this diagnostic data.

The microphone is released when detection is paused, Codex is using its microphone, the computer/display sleeps, or the app quits. macOS retains its standard microphone privacy indicator. A static menu-bar icon opens a compact popover with settings and pause controls; no standalone app window is created.

Apple is responsible for Speech framework internals, model availability/downloads, and operating-system diagnostics. “No transcript logging” describes this app’s implementation, not an audit of the operating system. Once Codex Voice opens, the conversation is governed by Codex/OpenAI settings and policies separately.

To remove the app: disable launch at login, quit Hey Voice, remove the app, and optionally remove its entries in macOS Privacy & Security. Preferences use the bundle identifier `io.github.heyvoice.companion`.
