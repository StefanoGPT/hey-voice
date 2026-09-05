import AppKit
import ApplicationServices

@MainActor
enum HotkeySender {
    static var trusted: Bool { AXIsProcessTrusted() }
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func prepareTarget() async throws {
        guard trusted else { throw CompanionError.message("Allow Hey Voice in System Settings → Privacy & Security → Accessibility, then try again.") }
        guard let url = CodexTarget.url else { throw CompanionError.message("Install the Codex / ChatGPT desktop app before using Hey Voice.") }
        if NSRunningApplication.runningApplications(withBundleIdentifier: CodexTarget.bundleID).isEmpty {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            try await Task.sleep(for: .seconds(2))
        }
    }

    static func post(_ hotkey: Hotkey) throws {
        guard trusted else { throw CompanionError.message("Accessibility permission is required to send the voice shortcut.") }
        let held = CGEventSource.flagsState(.combinedSessionState)
        guard held.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift]).isEmpty else {
            throw CompanionError.message("A modifier key is held down. Release it before trying again.")
        }
        let source = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: hotkey.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: hotkey.keyCode, keyDown: false) else {
            throw CompanionError.message("macOS could not create the keyboard shortcut.")
        }
        down.flags = hotkey.flags; up.flags = hotkey.flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
