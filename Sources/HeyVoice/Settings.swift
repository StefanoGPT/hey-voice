import AppKit
import CoreGraphics
import HeyVoiceCore

struct Hotkey: Codable, Equatable {
    var keyCode: UInt16 = 22
    var command = true
    var option = false
    var control = false
    var shift = false
    var keyLabel = "6"

    var display: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + keyLabel
    }
    var flags: CGEventFlags {
        var flags: CGEventFlags = []
        if command { flags.insert(.maskCommand) }
        if option { flags.insert(.maskAlternate) }
        if control { flags.insert(.maskControl) }
        if shift { flags.insert(.maskShift) }
        return flags
    }
    static func from(_ event: NSEvent) -> Hotkey? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !modifiers.intersection([.command, .control, .option]).isEmpty,
              let label = event.charactersIgnoringModifiers, !label.isEmpty else { return nil }
        let special: [UInt16: String] = [36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc", 123: "←", 124: "→", 125: "↓", 126: "↑"]
        return Hotkey(keyCode: event.keyCode, command: modifiers.contains(.command),
                      option: modifiers.contains(.option), control: modifiers.contains(.control),
                      shift: modifiers.contains(.shift), keyLabel: special[event.keyCode] ?? label.uppercased())
    }
}

struct Preferences: Codable {
    var keyword = "Voice"
    var locale = "en-US"
    var hotkey = Hotkey()

    static func load() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey: "preferences"),
              var value = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        value.keyword = WakeWordEdit(saved: value.keyword).saved
        return value
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "preferences") }
    }
}

enum CodexTarget {
    static let bundleID = "com.openai.codex"
    static var url: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }
}
