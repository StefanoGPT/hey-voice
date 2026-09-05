# Contributing

Use macOS 15+ and Xcode 16+. Open `Package.swift` in Xcode or use `swift test` and `scripts/build-app.sh`. No package installation is required.

Keep changes focused, preserve on-device-only processing, and never log user audio/transcripts. Do not introduce an API key requirement, third-party telemetry, automatic cloud fallback, hidden microphone indicators, or private Codex APIs.

Wake behavior changes should include regression tests for false triggers, stale recognition callbacks, quiet-time/cooldown behavior, and microphone handoff where applicable. A passing policy test does not replace testing with a microphone and the actual desktop voice app.

When reporting bugs, provide macOS and app versions, architecture, selected recognition language, microphone type, and concise reproduction steps. Do not attach transcripts, ambient recordings, credentials, or private Codex task contents. `--self-check` outputs capability booleans only.

Community previews and optional notarized releases have separate checks in `docs/RELEASING.md`. Keep signing keys, keychain profiles, notarization credentials, and local provisioning files out of commits.
