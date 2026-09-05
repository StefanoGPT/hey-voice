import AppKit
import ApplicationServices

/// A temporary active filter, installed only while the visible recorder has focus.
/// It consumes the chosen key's down/up pair before global hotkeys see it. It never
/// stores typed text or keeps a background keyboard listener after recording.
@MainActor
final class ShortcutCapture {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timeout: Timer?
    private var observers: [NSObjectProtocol] = []
    private var hasFocus: (() -> Bool)?
    private var completion: ((Hotkey?) -> Void)?
    private var pendingKey: UInt16?
    private var pendingHotkey: Hotkey?

    func start(hasFocus: @escaping () -> Bool, completion: @escaping (Hotkey?) -> Void) -> Bool {
        stop()
        guard AXIsProcessTrusted() else { return false }
        self.hasFocus = hasFocus; self.completion = completion
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                return MainActor.assumeIsolated {
                    Unmanaged<ShortcutCapture>.fromOpaque(info).takeUnretainedValue().handle(type, event)
                }
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap, let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { stop(); return false }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        timeout = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.finish(nil) }
        }
        for name in [NSWindow.didResignKeyNotification, NSApplication.didResignActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.finish(nil) }
            })
        }
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            finish(nil); return Unmanaged.passUnretained(event)
        }
        guard hasFocus?() == true else { finish(nil); return Unmanaged.passUnretained(event) }
        let key = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyDown {
            guard pendingKey == nil else { return nil }
            if key == 53 { pendingKey = key; return nil }
            if let native = NSEvent(cgEvent: event), let hotkey = Hotkey.from(native) {
                pendingKey = key; pendingHotkey = hotkey
            }
            return nil
        }
        if type == .keyUp {
            if pendingKey == key { finish(pendingHotkey) }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    func cancel() { finish(nil) }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
        timeout?.invalidate(); timeout = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        hasFocus = nil; completion = nil; pendingKey = nil; pendingHotkey = nil
    }

    private func finish(_ hotkey: Hotkey?) {
        let callback = completion
        stop()
        callback?(hotkey)
    }
}
