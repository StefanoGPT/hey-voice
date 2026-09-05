import AppKit
import AVFoundation
import Combine
import ServiceManagement
import Speech
import HeyVoiceCore

@MainActor
final class CompanionController: ObservableObject {
    @Published var preferences = Preferences.load()
    @Published private(set) var enabled = false
    @Published private(set) var busy = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var waitingReason: String?
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    var onWillDispatch: (() -> Void)?
    private let speech = SpeechListener()
    private var gate = WakeGate()
    private var timer: Timer?
    private var failures = 0
    private var activationTask: Task<Void, Never>?
    private var activationID = UUID()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var suspensionReasons = Set<String>()
    private var lastKeyword = ""
    private var lastLocale = ""
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    init() {
        let center = NSWorkspace.shared.notificationCenter
        let pairs: [(Notification.Name, String, Bool)] = [
            (NSWorkspace.willSleepNotification, "sleep", true),
            (NSWorkspace.didWakeNotification, "sleep", false),
            (NSWorkspace.sessionDidResignActiveNotification, "session", true),
            (NSWorkspace.sessionDidBecomeActiveNotification, "session", false),
            (NSWorkspace.screensDidSleepNotification, "screen", true),
            (NSWorkspace.screensDidWakeNotification, "screen", false)
        ]
        for (name, reason, suspended) in pairs {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.suspend(reason, value: suspended) }
            })
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func restoreIfRequested() {
        if UserDefaults.standard.bool(forKey: "detectionEnabled"),
           AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
           SFSpeechRecognizer.authorizationStatus() == .authorized, HotkeySender.trusted {
            activateDetection()
        }
    }

    func savePreferences() {
        preferences.save()
        if preferences.keyword != lastKeyword || preferences.locale != lastLocale {
            speech.stop()
            lastKeyword = preferences.keyword; lastLocale = preferences.locale
        }
    }

    func toggle() {
        if enabled || busy { pause() }
        else { Task { await enable() } }
    }

    func pause() {
        activationID = UUID()
        activationTask?.cancel(); activationTask = nil
        enabled = false; busy = false; gate.enabled = false
        UserDefaults.standard.set(false, forKey: "detectionEnabled")
        speech.stop(); waitingReason = nil
        Diagnostics.update(["enabled": false, "engineRunning": false, "microphoneCapturing": false,
                            "preparingRecognition": false, "gateAllowsListening": false])
    }

    func enable() async {
        guard !busy, !enabled else { return }
        guard WakePhrase.validKeyword(preferences.keyword) else {
            errorMessage = "Choose one word after Hey, using 2–24 letters."; return
        }
        preferences.keyword = preferences.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        preferences.save()
        guard CodexTarget.url != nil else { errorMessage = "Install the Codex / ChatGPT desktop app before enabling detection."; return }
        busy = true; errorMessage = nil
        let token = UUID(); activationID = token
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        guard activationID == token else { return }
        guard microphone else { busy = false; errorMessage = "Enable Microphone access for Hey Voice in System Settings → Privacy & Security."; return }
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard activationID == token else { return }
        busy = false
        guard speechStatus == .authorized else { errorMessage = "Enable Speech Recognition access for Hey Voice in System Settings → Privacy & Security."; return }
        guard HotkeySender.trusted else {
            HotkeySender.requestPermission()
            errorMessage = "Allow Hey Voice in Privacy & Security → Accessibility, then click Enable again."; return
        }
        activateDetection()
    }

    private func activateDetection() {
        errorMessage = nil; failures = 0; enabled = true; gate.enabled = true
        UserDefaults.standard.set(true, forKey: "detectionEnabled")
        tick()
    }

    private func suspend(_ reason: String, value: Bool) {
        if value { suspensionReasons.insert(reason) } else { suspensionReasons.remove(reason) }
        gate.suspended = !suspensionReasons.isEmpty
        if value {
            activationID = UUID(); activationTask?.cancel(); activationTask = nil; busy = false
            speech.stop()
        }
        gate.deferListening(now: now, seconds: 2)
    }

    private func tick() {
        guard enabled else { return }
        Diagnostics.update(["enabled": enabled, "engineRunning": speech.isRunning,
                            "preparingRecognition": speech.isPreparing, "microphoneCapturing": speech.isRunning && !speech.isPreparing,
                            "audioSeconds": speech.audioSeconds, "audioPeak": speech.maximumLevel])
        guard HotkeySender.trusted,
              AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
              SFSpeechRecognizer.authorizationStatus() == .authorized else {
            fail("A required permission was removed. Restore it in Privacy & Security, then enable detection again."); return
        }
        let activity = AudioActivityMonitor.snapshot()
        gate.observe(activity, now: now)
        Diagnostics.update(["targetInput": activity.targetInput, "audioActivityKnown": activity.known,
                            "gateAllowsListening": gate.canListen(now: now), "busy": busy])
        let reason: String?
        if gate.suspended { reason = "Detection resumes when the Mac is awake and your desktop is active." }
        else if !activity.known { reason = "Waiting for Codex microphone activity information." }
        else if activity.targetInput { reason = "Codex is already using the microphone. Detection resumes when Voice closes." }
        else if speech.isPreparing { reason = "Preparing on-device recognition for your wake phrase…" }
        else if now < gate.allowedAfter { reason = "Listening resumes in \(Int(ceil(gate.allowedAfter - now))) s." }
        else { reason = nil }
        if waitingReason != reason { waitingReason = reason }
        guard gate.canListen(now: now), !busy else { speech.stop(); return }
        if speech.isRunning {
            // macOS may end dictation requests; rotate proactively with a fresh transcript.
            if now - speech.startedAt > 50 { speech.stop() }
            else { return }
        }
        guard WakePhrase.validKeyword(preferences.keyword) else { fail("Choose one word after Hey, using 2–24 letters."); return }
        do {
            try speech.start(locale: preferences.locale, phrase: "Hey \(preferences.keyword)") { [weak self] words, audioTime in
                guard let self else { return }
                self.failures = 0
                let matches = WakePhrase.matches(words, keyword: self.preferences.keyword, audioTime: audioTime)
                Diagnostics.update(["phraseMatched": matches])
                if matches { self.wake() }
            } onEnd: { [weak self] failure in
                guard let self else { return }
                if let failure {
                    self.failures += 1
                    if self.failures >= 5 { self.fail("Recognition stopped repeatedly. \(failure)"); return }
                }
                self.gate.deferListening(now: self.now, seconds: min(8, pow(2, Double(self.failures))))
            }
        } catch { fail(error.localizedDescription) }
    }

    private func fail(_ message: String) {
        pause(); errorMessage = message
    }

    private func wake() {
        // Re-read synchronously at trigger time, not just on the last timer tick.
        gate.observe(AudioActivityMonitor.snapshot(), now: now)
        guard !busy, gate.trigger(now: now) else { return }
        Diagnostics.event("wakeAccepted")
        speech.stop()
        dispatchShortcut()
    }

    func testShortcut() {
        guard !busy else { return }
        let activity = AudioActivityMonitor.snapshot()
        guard !activity.blocksDetection else {
            errorMessage = activity.targetInput ? "Codex is already using the microphone. Close Voice before testing again." : "macOS microphone activity is temporarily unavailable. Try again."; return
        }
        speech.stop()
        dispatchShortcut()
    }

    private func dispatchShortcut() {
        busy = true; errorMessage = nil
        onWillDispatch?()
        let token = UUID(); activationID = token
        let saved = preferences
        activationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await HotkeySender.prepareTarget()
                guard !Task.isCancelled, self.activationID == token else { return }
                guard !AudioActivityMonitor.snapshot().blocksDetection else {
                    self.busy = false; return
                }
                try HotkeySender.post(saved.hotkey)
                Diagnostics.update(["shortcutPosted": true])
                Diagnostics.event("shortcutPosted")
                self.gate.didSendShortcut(now: self.now)
                self.busy = false
            } catch {
                guard self.activationID == token else { return }
                self.busy = false
                self.errorMessage = error.localizedDescription
                Diagnostics.update(["shortcutPosted": false, "shortcutError": error.localizedDescription])
            }
        }
    }

    func setLoginItem(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch { errorMessage = "Could not change launch at login: \(error.localizedDescription)" }
    }

    func shutdown() {
        activationID = UUID(); activationTask?.cancel()
        speech.stop(); timer?.invalidate()
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}
