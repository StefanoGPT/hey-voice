# Release checklist

## Source preview

- Pass `swift test` and build both architectures with `UNIVERSAL=1 scripts/build-app.sh`.
- Check the menu-bar popover, custom keyword persistence, shortcut capture, invalid input, error layout, and pause behavior. Expand Options and verify the fixed panel stays below the menu bar and scrolls internally.
- Record an actual registered global voice shortcut with a physical keyboard; verify no Voice call starts during recording. Verify the event tap is removed after success, Escape, focus loss, and timeout.
- Ensure documentation distinguishes verified checks from microphone/recognition/handoff tests still pending.
- Review `git diff --check` and all files staged for publication. No local paths, credentials, signing materials, build caches, or private screenshots.
- Label the first source publication a developer preview until live tests are complete.

## Consumer binary

- Run at least 30 spoken activations from realistic couch distance; record successes, misses, and latency without storing conversation audio.
- Verify at least two custom keywords, including a word other than Voice or Chat, with the selected language.
- Verify the companion releases the microphone before Codex begins its call and re-arms after the call ends.
- Verify normal Chrome playback, music, silent browser streams, and unrelated microphone use do not block wake detection. Verify Codex speaking during an active call cannot re-trigger Voice. Arbitrary media saying the exact phrase can trigger the companion; do not claim acoustic echo cancellation or speaker verification.
- Verify duplicate partial recognition results and repeated wake phrases cannot repeatedly invoke the hotkey during a call.
- Verify the configured shortcut with Codex backgrounded, foregrounded, closed, and after a slow cold launch. The current bridge has a two-second cold-launch wait, not a readiness API; do not claim universal cold-start reliability without testing.
- Test missing/revoked Microphone, Speech Recognition, and Accessibility permissions, unavailable speech language, unplugged devices, input-device switching, display/system sleep, desktop/session changes, and restart.
- Run a one-hour soak test and measure idle CPU/energy and microphone recovery. Check that speech rollover and retries do not accumulate sessions or duplicate events.
- Test launch at login from Applications, persisted pause, and duplicate app launches.
- Check permission prompts and recognition on a fresh account; developer machine permissions can be inherited or previously granted.
- Validate arm64 and x86_64 on actual representative hardware before listing them as tested. Verify macOS 15 separately from later versions.
- Set final bundle identity, version/build number, application name, and release notes before signing.
- Sign with Developer ID Application, notarize, staple, and pass Gatekeeper assessment using `scripts/package-release.sh`.
- Test the downloaded ZIP on a clean Mac. Publish only the final notarized ZIP and checksum; keep signing/notarization material private.

## Known scope boundaries

The companion opens Voice using a keyboard shortcut. It does not forward buffered speech into Codex, guarantee the call has connected, end a call, choose a task, authenticate a speaker, or bypass any Codex permission. No sound or additional live listening display is implemented.
