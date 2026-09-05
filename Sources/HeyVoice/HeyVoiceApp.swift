import AppKit
import Combine
import Speech
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: CompanionController!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var hostingController: NSHostingController<CompanionPopover>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier).count > 1 {
            NSApplication.shared.terminate(nil); return
        }
        installMainMenu()
        controller = CompanionController()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = VoiceBrand.icon(size: 20)
        statusItem.button?.toolTip = "Hey Voice"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        // Static icon, transient panel; no standalone settings window or live indicator.
        popover.behavior = .transient
        popover.animates = false
        hostingController = NSHostingController(rootView: CompanionPopover(controller: controller))
        // SwiftUI's changing preferred size otherwise moves the popover upward when
        // Options expands. AppKit owns a fixed, screen-bounded frame; content scrolls.
        hostingController.sizingOptions = []
        popover.contentViewController = hostingController
        controller.onWillDispatch = { [weak self] in self?.popover.performClose(nil) }
        controller.restoreIfRequested()
        if !UserDefaults.standard.bool(forKey: "hasOpenedPopover") {
            UserDefaults.standard.set(true, forKey: "hasOpenedPopover")
            showPopover()
        }
    }

    private func installMainMenu() {
        let bar = NSMenu()
        let application = NSMenuItem()
        let appMenu = NSMenu(title: "Hey Voice")
        let quit = NSMenuItem(title: "Quit Hey Voice", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quit)
        application.submenu = appMenu; bar.addItem(application)
        let editing = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        for (title, selector, key) in [
            ("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
            ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")
        ] {
            editMenu.addItem(NSMenuItem(title: title, action: NSSelectorFromString(selector), keyEquivalent: key))
        }
        editing.submenu = editMenu; bar.addItem(editing)
        NSApplication.shared.mainMenu = bar
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }
    private func showPopover() {
        guard let button = statusItem.button else { return }
        let visibleHeight = button.window?.screen?.visibleFrame.height ?? 600
        let height = min(420, max(220, visibleHeight - 24))
        let size = NSSize(width: 340, height: height)
        hostingController.rootView = CompanionPopover(controller: controller, panelHeight: height)
        hostingController.view.setFrameSize(size)
        popover.contentSize = size
        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover(); return true
    }
    func applicationWillTerminate(_ notification: Notification) { controller?.shutdown() }
}

@main
struct HeyVoiceApp {
@MainActor
static func main() throws {
if let index = CommandLine.arguments.firstIndex(of: "--diagnostics"), CommandLine.arguments.count > index + 1 {
    Diagnostics.destination = URL(fileURLWithPath: CommandLine.arguments[index + 1])
}
if CommandLine.arguments.contains("--self-check") {
    let activity = AudioActivityMonitor.snapshot()
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    let report: [String: Any] = [
        "audioActivityAvailable": activity.known,
        "otherAppUsingMicrophone": activity.otherInput,
        "otherAppPlayingAudio": activity.otherOutput,
        "codexUsingMicrophone": activity.targetInput,
        "onDeviceEnglishAvailable": recognizer?.supportsOnDeviceRecognition ?? false,
        "accessibilityGranted": HotkeySender.trusted,
        "targetFound": CodexTarget.url != nil,
        "microphoneOpened": false
    ]
    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    app.run()
}
}
}
