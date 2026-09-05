import Foundation

/// Editing a word never replaces the active selection until Save succeeds.
public struct WakeWordEdit: Equatable, Sendable {
    public private(set) var saved: String
    public var draft: String
    public var hasChanges: Bool { draft != saved }
    public var isValid: Bool { WakePhrase.validKeyword(draft) }

    public init(saved: String) {
        let word = WakePhrase.validKeyword(saved)
            ? saved.trimmingCharacters(in: .whitespacesAndNewlines) : "Voice"
        self.saved = word
        self.draft = word
    }

    @discardableResult
    public mutating func save() -> Bool {
        guard isValid else { return false }
        saved = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = saved
        return true
    }
}
