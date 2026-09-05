import CoreAudio
import Foundation
import AppKit
import Darwin
import HeyVoiceCore

/// Reads audio activity flags only. Does not record system audio or request a process tap.
enum AudioActivityMonitor {
    static func snapshot() -> AudioActivity {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                                mScope: kAudioObjectPropertyScopeGlobal,
                                                mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr,
              size % UInt32(MemoryLayout<AudioObjectID>.size) == 0 else { return AudioActivity(known: false) }
        if size == 0 { return AudioActivity() }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let result = processes.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(system, &address, 0, nil, &size, bytes.baseAddress!)
        }
        guard result == noErr else { return AudioActivity(known: false) }
        var activity = AudioActivity()
        let targetPIDs = Set(NSRunningApplication.runningApplications(withBundleIdentifier: CodexTarget.bundleID).map(\.processIdentifier))
        let targetPath = CodexTarget.url?.path
        for process in processes.prefix(Int(size) / MemoryLayout<AudioObjectID>.size) {
            guard let pid: Int32 = read(process, kAudioProcessPropertyPID) else {
                activity.known = false; continue
            }
            if pid == ProcessInfo.processInfo.processIdentifier { continue }
            guard let input: UInt32 = read(process, kAudioProcessPropertyIsRunningInput) else {
                activity.known = false; continue
            }
            let output: UInt32 = read(process, kAudioProcessPropertyIsRunningOutput) ?? 0
            activity.otherInput = activity.otherInput || input != 0
            activity.otherOutput = activity.otherOutput || output != 0
            if input != 0 && belongsToCodex(pid, targetPIDs: targetPIDs, targetPath: targetPath) {
                activity.targetInput = true
            }
        }
        return activity
    }

    private static func belongsToCodex(_ pid: Int32, targetPIDs: Set<Int32>, targetPath: String?) -> Bool {
        if targetPIDs.contains(pid) { return true }
        var path = [CChar](repeating: 0, count: 4096)
        if let targetPath, proc_pidpath(pid, &path, UInt32(path.count)) > 0,
           String(cString: path).hasPrefix(targetPath + "/") { return true }
        // Native voice hosts may live outside the app bundle. Follow only a short
        // process ancestry chain, without reading arguments or user content.
        var ancestor = pid
        for _ in 0..<6 {
            var info = proc_bsdinfo()
            let count = proc_pidinfo(ancestor, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
            guard count == MemoryLayout<proc_bsdinfo>.size else { return false }
            let parent = Int32(info.pbi_ppid)
            if targetPIDs.contains(parent) { return true }
            if parent <= 1 || parent == ancestor { return false }
            ancestor = parent
        }
        return false
    }

    private static func read<T: FixedWidthInteger>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> T? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                mElement: kAudioObjectPropertyElementMain)
        var value: T = 0
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }
}
