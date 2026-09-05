import Foundation

/// Explicit developer diagnostics only. Never contains audio, transcript text,
/// filenames from conversations, or individual keystrokes.
@MainActor
enum Diagnostics {
    static var destination: URL?
    private static var values: [String: Any] = [:]
    private static var events: [[String: Any]] = []
    private static var counts: [String: Int] = [:]
    static func event(_ name: String, _ fields: [String: Any] = [:]) {
        guard destination != nil else { return }
        var entry = fields
        entry["event"] = name
        entry["at"] = ISO8601DateFormatter().string(from: Date())
        events.append(entry)
        counts[name, default: 0] += 1
        if events.count > 30 { events.removeFirst(events.count - 30) }
        update(["events": events, "eventCounts": counts])
    }
    static func update(_ fields: [String: Any]) {
        guard let destination else { return }
        values.merge(fields) { _, new in new }
        values["updatedAt"] = ISO8601DateFormatter().string(from: Date())
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: destination, options: .atomic)
    }
}
