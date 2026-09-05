import Foundation

public struct SpokenWord: Equatable, Sendable {
    public let text: String
    public let start: TimeInterval
    public let duration: TimeInterval
    public init(_ text: String, start: TimeInterval, duration: TimeInterval) {
        self.text = text; self.start = start; self.duration = duration
    }
}

public enum WakePhrase {
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    public static func validKeyword(_ text: String) -> Bool {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (2...24).contains(word.count) && word.unicodeScalars.allSatisfy(CharacterSet.letters.contains)
    }

    /// Match a standalone "Hey <word>" utterance, never a substring in a sentence.
    /// Recognition timestamps are measured in seconds of audio appended to the request.
    public static func matches(_ words: [SpokenWord], keyword: String, audioTime: TimeInterval) -> Bool {
        guard validKeyword(keyword), let last = words.last else { return false }
        // Apple can deliver partial segments with both timestamps and durations
        // unset. Zero is not evidence that the user spoke at session start.
        // Without timing, accept only the entire exact phrase, never a suffix
        // that could be part of an ordinary sentence. Call only on fresh results.
        if words.allSatisfy({ $0.start == 0 && $0.duration == 0 }) {
            return normalize(words.map(\.text).joined(separator: " ")) == "hey \(normalize(keyword))"
        }
        guard audioTime - (last.start + last.duration) <= 2.5,
              audioTime >= last.start else { return false }
        var beginning = words.count - 1
        while beginning > 0 {
            let previous = words[beginning - 1]
            if words[beginning].start - (previous.start + previous.duration) >= 0.9 { break }
            beginning -= 1
        }
        let utterance = normalize(words[beginning...].map(\.text).joined(separator: " "))
        return utterance == "hey \(normalize(keyword))"
    }
}

public struct AudioActivity: Equatable, Sendable {
    public var otherInput: Bool
    public var otherOutput: Bool
    public var targetInput: Bool
    public var known: Bool
    public init(otherInput: Bool = false, otherOutput: Bool = false, targetInput: Bool = false, known: Bool = true) {
        self.otherInput = otherInput; self.otherOutput = otherOutput; self.targetInput = targetInput; self.known = known
    }
    public var blocksDetection: Bool { !known || targetInput }
}

/// Uses monotonic time, so clock changes cannot bypass cooldown or quiet time.
public struct WakeGate: Sendable {
    public var enabled = false
    public var suspended = false
    public private(set) var activity = AudioActivity(known: false)
    private var startupUntil: TimeInterval = 0
    private var quietUntil: TimeInterval = 0
    private var deferredUntil: TimeInterval = 0
    private var hasObservedActivity = false
    public var allowedAfter: TimeInterval { max(startupUntil, quietUntil, deferredUntil) }
    public let quietPeriod: TimeInterval
    public let cooldown: TimeInterval

    public init(quietPeriod: TimeInterval = 1.5, cooldown: TimeInterval = 8) {
        self.quietPeriod = quietPeriod; self.cooldown = cooldown
    }
    public mutating func observe(_ activity: AudioActivity, now: TimeInterval) {
        let wasBlocked = hasObservedActivity && self.activity.blocksDetection
        hasObservedActivity = true
        self.activity = activity
        // Once Codex has taken the microphone, its active stream protects the
        // call. The startup timeout no longer needs to outlive a short call.
        if activity.known && activity.targetInput { startupUntil = 0 }
        if activity.blocksDetection || wasBlocked {
            quietUntil = max(quietUntil, now + quietPeriod)
        }
    }
    public func canListen(now: TimeInterval) -> Bool {
        enabled && !suspended && !activity.blocksDetection && now >= allowedAfter
    }
    public mutating func trigger(now: TimeInterval) -> Bool {
        guard canListen(now: now) else { return false }
        didSendShortcut(now: now)
        return true
    }
    public mutating func didSendShortcut(now: TimeInterval) {
        startupUntil = now + cooldown
    }
    public mutating func deferListening(now: TimeInterval, seconds: TimeInterval) {
        deferredUntil = max(deferredUntil, now + seconds)
    }
}
