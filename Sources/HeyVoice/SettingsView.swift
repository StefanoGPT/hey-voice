import AppKit
import SwiftUI
import HeyVoiceCore

struct CompanionPopover: View {
    @ObservedObject var controller: CompanionController
    var panelHeight: CGFloat = 420
    @State private var showOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: VoiceBrand.icon(size: 22)).accessibilityHidden(true)
                Text("Hey Voice").font(.headline)
                Spacer()
                Text("for Codex").font(.caption).foregroundStyle(.secondary)
            }.padding(16)
            Divider()
            ScrollView {
            VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Hey").font(.system(size: 21, weight: .medium, design: .rounded))
                TextField("Voice", text: $controller.preferences.keyword)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Word after Hey")
            }
            Text("Say “Hey \(controller.preferences.keyword)”, then wait for Voice to open.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !WakePhrase.validKeyword(controller.preferences.keyword) {
                Text("Choose one word with 2–24 letters.").font(.caption).foregroundStyle(.red)
            }
            HStack {
                Text("Voice shortcut").font(.callout)
                Spacer()
                ShortcutRecorder(hotkey: $controller.preferences.hotkey).frame(width: 110, height: 26)
                Button("Test") { controller.testShortcut() }.disabled(controller.busy)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Match the shortcut in Codex:").foregroundStyle(.secondary)
                Text("Settings → Voice → Voice chat hotkey").fontWeight(.medium)
                Button("Open Codex Settings ↗") {
                    NSWorkspace.shared.open(URL(string: "codex://settings")!)
                }.buttonStyle(.link)
            }.font(.caption).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            DisclosureGroup("Options", isExpanded: $showOptions) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at login", isOn: Binding(get: { controller.launchAtLogin }, set: controller.setLoginItem))
                    Picker("Language", selection: $controller.preferences.locale) {
                        Text("English (US)").tag("en-US")
                        Text("English (UK)").tag("en-GB")
                        Text("Italian").tag("it-IT")
                        Text("French").tag("fr-FR")
                        Text("German").tag("de-DE")
                        Text("Spanish").tag("es-ES")
                    }
                    Text("Other apps can keep playing audio. Detection pauses while Codex uses the microphone. macOS keeps its own microphone privacy indicator.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Microphone & Speech Permissions…") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
                    }.buttonStyle(.link).font(.caption)
                    Link("Setup guide", destination: URL(string: "https://github.com/StefanoGPT/hey-voice/blob/main/docs/INSTALL.md")!)
                        .font(.caption)
                    Link("Created by @StefanoGPT", destination: URL(string: "https://x.com/StefanoGPT")!)
                        .font(.caption)
                }.padding(.top, 9)
            }.font(.callout)
            if let error = controller.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let reason = controller.waitingReason {
                Text(reason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            VStack(alignment: .leading, spacing: 9) {
            HStack {
                Button(controller.enabled || controller.busy ? "Pause Detection" : "Enable Detection") { controller.toggle() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!WakePhrase.validKeyword(controller.preferences.keyword) && !controller.enabled && !controller.busy)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.borderless).foregroundStyle(.secondary)
            }
            Text("On-device. No audio saved.").font(.caption2).foregroundStyle(.tertiary)
            }.padding(16)
        }
        .frame(width: 340, height: panelHeight)
        .onChange(of: controller.preferences.keyword) { _, _ in controller.savePreferences() }
        .onChange(of: controller.preferences.locale) { _, _ in controller.savePreferences() }
        .onChange(of: controller.preferences.hotkey) { _, _ in controller.savePreferences() }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var hotkey: Hotkey
    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onRecord = { hotkey = $0 }
        return button
    }
    func updateNSView(_ button: RecorderButton, context: Context) {
        button.shortcutTitle = hotkey.display
        if !button.recording { button.title = hotkey.display }
        button.onRecord = { hotkey = $0 }
    }
}

final class RecorderButton: NSButton {
    var onRecord: ((Hotkey) -> Void)?
    var shortcutTitle = "⌘6"
    private(set) var recording = false
    private let capture = ShortcutCapture()
    override var acceptsFirstResponder: Bool { true }
    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self; action = #selector(beginRecording)
        setAccessibilityLabel("Record voice keyboard shortcut")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc private func beginRecording() {
        recording = true; title = "Press shortcut…"
        window?.makeFirstResponder(self)
        let started = capture.start(hasFocus: { [weak self] in
            guard let self else { return false }
            return self.recording && self.window?.isKeyWindow == true && self.window?.isVisible == true && NSApp.isActive
        }, completion: { [weak self] hotkey in
            guard let self else { return }
            self.recording = false
            if let hotkey { self.shortcutTitle = hotkey.display; self.onRecord?(hotkey) }
            self.title = self.shortcutTitle
            self.window?.makeFirstResponder(nil)
        })
        if !started {
            recording = false; title = "Allow Accessibility"
            HotkeySender.requestPermission()
        }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event); return true
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { capture.cancel(); return }
        guard let hotkey = Hotkey.from(event) else { title = "Include ⌘, ⌃ or ⌥"; return }
        capture.stop()
        recording = false; title = hotkey.display; onRecord?(hotkey)
        window?.makeFirstResponder(nil)
    }
    override func resignFirstResponder() -> Bool {
        capture.stop()
        recording = false; title = shortcutTitle
        return super.resignFirstResponder()
    }
}
