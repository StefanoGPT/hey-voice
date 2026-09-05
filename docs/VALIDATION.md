# Validation — 0.1.2 community preview

Checked on 2026-09-05 with macOS 26.1 and Xcode/Swift 6.2.4, on Apple silicon.

Version 0.1.1 adds a full-width, 32-point-high Options control. The chevron, label, and empty row area use one button. Expansion and collapse were verified in the installed companion, with the compact panel and internal scrolling retained. The community packaging also includes the corrected creator credit.

Version 0.1.2 separates the wake-word draft from the saved phrase, adds Save and Return-to-save, and shows the installed bundle version in the footer (with the build number in its tooltip). Four regression tests cover draft isolation, invalid saves, whitespace trimming, and recovery from invalid legacy preferences. Saving leaves detection enabled or paused as it was. In the installed app, a draft changed to Chat kept Voice as the saved phrase; Save committed Chat while detection stayed paused. Return then saved Voice again, detection was re-enabled, and v0.1.2 was visibly verified in the footer.

## Verified

- `swift test`: 22 tests, zero failures. Covers custom keyword matching, whole-word/utterance boundaries, stale transcripts, untimed partial results late in a session, disabled/suspended behavior, unknown audio state, cooldown, Codex microphone handoff policy, and the regression that unrelated microphone/playback activity must not block activation. Handoff regressions cover short and long calls, manual shortcuts, unrelated/unknown audio, and preservation of recovery/suspension delays.
- Native release build and universal arm64 + x86_64 build succeed. Both architectures are present in the packaged executable.
- Bundle metadata and entitlements pass `plutil`; shell packaging scripts pass syntax validation; the local app passes strict code signature verification.
- The local preview is signed with an Apple Development identity and installed in Applications. This is a development signature, not a Developer ID distribution signature.
- On-device English availability and CoreAudio activity queries succeed on the test Mac. The desktop Codex app is found by bundle identity despite its installed name being ChatGPT.
- The app starts actual microphone capture after permission setup. CoreAudio confirms an active input stream owned by Hey Voice.
- The compact menu-bar popover renders without a standalone window. Its frame is explicitly sized before presentation and bounded by available display height; internal content scrolls, with primary controls pinned below it. The updated whole panel is visibly within the screen.
- Custom word editing updates the displayed phrase, including a word other than Voice/Chat. Select-all works. The default was restored to Hey Voice.
- Shortcut capture saves ⌘6 under UI automation without opening a Codex call. OS event-tap inspection confirms one active companion tap during recording and zero immediately after completion. Physical-keyboard confirmation remains separate.
- The stale Accessibility entry from an earlier ad-hoc build was replaced with the installed signed app. The app then enables detection without the earlier permission error; the subsequent signed update retains that authorization.
- A Chrome audio helper was identified as the reason for the initial blanket playback block. That policy was removed. The current policy only suppresses automatic activation for Codex microphone use, unknown required activity, cooldown, or suspension.

## Spoken-wake investigation

The tester initially reported that saying “Hey Voice” did not open Voice. Opt-in metadata diagnostics confirmed microphone input and recognition of the configured keyword, but no exact match in the best transcription. Some partial results had zero timestamps and durations, causing the previous freshness check to reject them after 2.5 seconds of listening. The matcher now handles untimed exact phrases, and the listener checks recognition alternatives for the exact phrase. Regression tests cover the timing bug and rejection of embedded phrases.

After that correction, the tester confirmed two real spoken activations. Diagnostics corroborated exact phrase matches followed by shortcut dispatch at 11:40:16 and 11:40:32 UTC; the second match came from a recognition alternative. Further attempts failed even though the microphone was active and the gate allowed listening: the keyword was recognized but the prefix was missing. These two successes establish basic operation, not reliable recognition.

The subsequent build adds an Apple custom language model weighted toward the configured phrase, generated from text only. On the test Mac, first preparation completed in about one second and generated roughly 8.5 MB of cached data. The microphone then started normally; Pause released input and Enable resumed capture, reusing the prepared model. Preparation has cancellation guards and a 30-second timeout with bounded retries. These are local runtime observations; repeated physical-voice accuracy with the custom model is still under test.

## Remaining validation beyond the community preview

The tester subsequently reported that the first wake usually worked, with failures when retrying immediately after closing Voice. The earlier fixed startup cooldown could outlast a short call. The updated gate cancels that startup timer only after observing known Codex microphone activity, then resumes 1.5 seconds after observing its release. Retry/sleep delays remain independent and cannot be cancelled by a call transition. Automated tests cover this policy; user-perceived end-to-end re-arm latency still needs measurement.

After the handoff update, the tester confirmed that the app worked well, including repeated use. This is a positive real-use confirmation on one Mac, not a measured accuracy percentage, a 30-trial benchmark, or cross-platform validation.

- Physical-keyboard verification of isolation against the currently registered Codex global hotkey, plus Escape, focus-loss, and timeout checks.
- Real spoken wake phrase → Codex voice connection → microphone handoff → end call → re-arm, repeated from realistic distance.
- Background playback tests against the actual microphone and desktop app. Unit tests verify the policy, not acoustic recognition quality or every helper-process lifecycle.
- Long-session recovery, device unplug/reconnect, sleep/login behavior, and measured idle energy use.
- Fresh-account permissions, macOS 15 testing, and runtime testing on Intel hardware.
- A clean-Mac downloaded-binary and first-launch approval test. Developer ID signing, notarization, and stapling are a separate optional future distribution path, not used by the OSS community preview.

Two physical voice successes were observed before the custom-model update. No reliable accuracy rate, wake latency, echo-cancellation capability, or completed notarization is claimed. See [RELEASING.md](RELEASING.md) for the full checklist.
