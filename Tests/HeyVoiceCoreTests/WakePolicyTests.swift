import XCTest
@testable import HeyVoiceCore

final class WakePolicyTests: XCTestCase {
    private func words(_ values: [String], offset: Double = 0) -> [SpokenWord] {
        values.enumerated().map { SpokenWord($0.element, start: offset + Double($0.offset) * 0.35, duration: 0.25) }
    }

    func testCustomKeywordAndCase() {
        XCTAssertTrue(WakePhrase.matches(words(["Hey", "Chat!"]), keyword: "chat", audioTime: 0.8))
        XCTAssertFalse(WakePhrase.matches(words(["Hey", "Voice"]), keyword: "Chat", audioTime: 0.8))
        XCTAssertTrue(WakePhrase.matches(words(["HEY", "Atlas"]), keyword: "Atlas", audioTime: 0.8))
    }
    func testPhraseMustBeWholeWordsAndStandalone() {
        for sentence in [["hey", "voicemail"], ["they", "voice"], ["say", "hey", "voice"], ["hey", "voice", "open"]] {
            XCTAssertFalse(WakePhrase.matches(words(sentence), keyword: "Voice", audioTime: 1.6), sentence.joined(separator: " "))
        }
    }
    func testLaterUtteranceAfterSilenceCanWake() {
        let transcription = words(["unrelated", "conversation"]) + words(["hey", "voice"], offset: 3)
        XCTAssertTrue(WakePhrase.matches(transcription, keyword: "Voice", audioTime: 3.8))
    }
    func testStaleTranscriptsAndEmptyResultsCannotWake() {
        XCTAssertFalse(WakePhrase.matches(words(["hey", "voice"]), keyword: "Voice", audioTime: 5))
        XCTAssertFalse(WakePhrase.matches([], keyword: "Voice", audioTime: 0))
        XCTAssertFalse(WakePhrase.matches(words(["hey", "voice"], offset: 5), keyword: "Voice", audioTime: 0))
    }
    func testKeywordValidation() {
        for value in ["Voice", "Chat", "Atlas", "Caffè", " Voice "] { XCTAssertTrue(WakePhrase.validKeyword(value)) }
        for value in ["", "a", "two words", "voice!", "123", String(repeating: "a", count: 25)] { XCTAssertFalse(WakePhrase.validKeyword(value)) }
    }
    func testFreshPartialWithUnsetTimingCanWakeLateInSession() {
        let partial = [SpokenWord("Hey", start: 0, duration: 0), SpokenWord("Voice", start: 0, duration: 0)]
        XCTAssertTrue(WakePhrase.matches(partial, keyword: "Voice", audioTime: 34.2))
        XCTAssertFalse(WakePhrase.matches(partial, keyword: "Chat", audioTime: 34.2))
    }
    func testUntimedPartialDoesNotGuessSentenceBoundaries() {
        for sentence in [["say", "hey", "voice"], ["a", "voice"], ["hey", "voice", "open"], ["hey", "voicemail"]] {
            let partial = sentence.map { SpokenWord($0, start: 0, duration: 0) }
            XCTAssertFalse(WakePhrase.matches(partial, keyword: "Voice", audioTime: 34.2))
        }
    }
    func testDisabledAndUnknownAudioFailClosed() {
        var gate = WakeGate()
        XCTAssertFalse(gate.trigger(now: 100))
        gate.enabled = true
        XCTAssertFalse(gate.trigger(now: 100))
        gate.observe(AudioActivity(), now: 100)
        XCTAssertTrue(gate.trigger(now: 100))
    }
    func testChromeAndOtherPlaybackNeverBlockDetection() {
        var gate = WakeGate(); gate.enabled = true
        gate.observe(AudioActivity(otherOutput: true), now: 10)
        XCTAssertTrue(gate.trigger(now: 10))
        gate.observe(AudioActivity(otherInput: true, otherOutput: true), now: 20)
        XCTAssertTrue(gate.trigger(now: 20))
    }
    func testCodexMicrophoneUseSuppressesUntilReleased() {
        var gate = WakeGate(); gate.enabled = true
        gate.observe(AudioActivity(otherInput: true, targetInput: true), now: 10)
        XCTAssertFalse(gate.canListen(now: 50))
        gate.observe(AudioActivity(otherInput: true, targetInput: true), now: 50)
        gate.observe(AudioActivity(), now: 50.1)
        XCTAssertFalse(gate.canListen(now: 51))
        XCTAssertTrue(gate.canListen(now: 52))
    }
    func testRepeatedPartialResultsOnlyTriggerOnceDuringCooldown() {
        var gate = WakeGate(); gate.enabled = true
        gate.observe(AudioActivity(), now: 100)
        XCTAssertTrue(gate.trigger(now: 100))
        XCTAssertFalse(gate.trigger(now: 100.1))
        XCTAssertFalse(gate.trigger(now: 107.99))
        XCTAssertTrue(gate.trigger(now: 108))
    }
    func testShortCallRearmsAfterReleaseInsteadOfFullStartupTimeout() {
        var gate = WakeGate(); gate.enabled = true
        gate.observe(AudioActivity(), now: 100)
        XCTAssertTrue(gate.trigger(now: 100))
        gate.didSendShortcut(now: 100.2)
        gate.observe(AudioActivity(targetInput: true), now: 100.5)
        gate.observe(AudioActivity(), now: 101)
        XCTAssertFalse(gate.canListen(now: 102.49))
        XCTAssertTrue(gate.trigger(now: 102.5))
        XCTAssertFalse(gate.trigger(now: 102.6))
    }
    func testLongCallRemainsBlockedPastStartupTimeout() {
        var gate = WakeGate(); gate.enabled = true
        gate.observe(AudioActivity(), now: 100)
        XCTAssertTrue(gate.trigger(now: 100))
        gate.observe(AudioActivity(targetInput: true), now: 101)
        XCTAssertFalse(gate.canListen(now: 200))
        gate.observe(AudioActivity(), now: 200)
        XCTAssertFalse(gate.canListen(now: 201.49))
        XCTAssertTrue(gate.canListen(now: 201.5))
    }
    func testUnrelatedOrUnknownAudioDoesNotCancelStartupProtection() {
        var gate = WakeGate(); gate.enabled = true
        gate.observe(AudioActivity(), now: 100)
        XCTAssertTrue(gate.trigger(now: 100))
        gate.observe(AudioActivity(otherInput: true, otherOutput: true), now: 101)
        gate.observe(AudioActivity(targetInput: true, known: false), now: 102)
        gate.observe(AudioActivity(), now: 103)
        XCTAssertFalse(gate.canListen(now: 107.99))
        XCTAssertTrue(gate.canListen(now: 108))
    }
    func testCallReleaseCannotEraseRecoveryDeferralOrSuspension() {
        var gate = WakeGate(); gate.enabled = true
        gate.observe(AudioActivity(), now: 100)
        XCTAssertTrue(gate.trigger(now: 100))
        gate.deferListening(now: 100, seconds: 20)
        gate.observe(AudioActivity(targetInput: true), now: 101)
        gate.observe(AudioActivity(), now: 102)
        XCTAssertFalse(gate.canListen(now: 119.99))
        gate.suspended = true
        XCTAssertFalse(gate.canListen(now: 120))
        gate.suspended = false
        XCTAssertTrue(gate.canListen(now: 120))
    }
    func testManualShortcutUsesSameHandoffAndReleasePolicy() {
        var gate = WakeGate(); gate.enabled = true
        gate.observe(AudioActivity(), now: 10)
        gate.didSendShortcut(now: 10)
        XCTAssertFalse(gate.canListen(now: 11))
        gate.observe(AudioActivity(targetInput: true), now: 11)
        gate.observe(AudioActivity(), now: 12)
        XCTAssertTrue(gate.canListen(now: 13.5))
    }
    func testSleepAndPauseOverrideCooldownExpiry() {
        var gate = WakeGate(); gate.enabled = true
        gate.observe(AudioActivity(), now: 10)
        gate.suspended = true
        XCTAssertFalse(gate.trigger(now: 1000))
        gate.suspended = false; gate.enabled = false
        XCTAssertFalse(gate.trigger(now: 1000))
    }
    func testUnknownAudioAfterQuietAndDeferredRearm() {
        var gate = WakeGate(); gate.enabled = true
        gate.observe(AudioActivity(), now: 10)
        gate.deferListening(now: 10, seconds: 20)
        gate.observe(AudioActivity(known: false), now: 11)
        gate.observe(AudioActivity(), now: 12)
        XCTAssertFalse(gate.trigger(now: 29))
        XCTAssertTrue(gate.trigger(now: 30))
    }
}
