import XCTest
@testable import HeyVoiceCore

final class WakeWordEditTests: XCTestCase {
    func testDeletingAndRetypingDoesNotReplaceSavedWord() {
        var edit = WakeWordEdit(saved: "Voice")
        for draft in ["", "C", "Chat"] {
            edit.draft = draft
            XCTAssertEqual(edit.saved, "Voice")
            XCTAssertTrue(edit.hasChanges)
        }
        XCTAssertTrue(edit.save())
        XCTAssertEqual(edit.saved, "Chat")
        XCTAssertFalse(edit.hasChanges)
    }
    func testInvalidSavePreservesPreviousSelection() {
        var edit = WakeWordEdit(saved: "Atlas")
        for draft in ["", "a", "two words", "Voice!"] {
            edit.draft = draft
            XCTAssertFalse(edit.save())
            XCTAssertEqual(edit.saved, "Atlas")
        }
    }
    func testSaveTrimsInputAndCanBeReloaded() {
        var edit = WakeWordEdit(saved: "Voice")
        edit.draft = "  Caffè \n"
        XCTAssertTrue(edit.save())
        XCTAssertEqual(edit.saved, "Caffè")
        XCTAssertEqual(WakeWordEdit(saved: edit.saved), edit)
    }
    func testInvalidLegacyPreferenceRecoversToDefault() {
        for value in ["", "a", "two words"] {
            XCTAssertEqual(WakeWordEdit(saved: value).saved, "Voice")
        }
    }
}
