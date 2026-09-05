import AVFoundation
import Speech
import HeyVoiceCore

/// Only the audio callback touches the request and frame counter, protected during teardown.
private final class AudioFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var seconds: TimeInterval = 0
    private var peak: Float = 0
    init(_ request: SFSpeechAudioBufferRecognitionRequest) { self.request = request }
    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard let request else { return }
        request.append(buffer)
        seconds += Double(buffer.frameLength) / buffer.format.sampleRate
        if let channel = buffer.floatChannelData?[0] {
            for index in 0..<Int(buffer.frameLength) { peak = max(peak, abs(channel[index])) }
        }
    }
    var audioTime: TimeInterval {
        lock.lock(); defer { lock.unlock() }; return seconds
    }
    var maximumLevel: Float {
        lock.lock(); defer { lock.unlock() }; return peak
    }
    func finish() {
        lock.lock(); defer { lock.unlock() }; request?.endAudio(); request = nil
    }
}

@MainActor
final class SpeechListener {
    private var engine: AVAudioEngine?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var preparationTask: Task<Void, Never>?
    private var preparationTimeout: Task<Void, Never>?
    private var feed: AudioFeed?
    private var generation = UUID()
    private var configurationObserver: NSObjectProtocol?
    private(set) var startedAt: TimeInterval = 0
    var isRunning: Bool { engine != nil || preparationTask != nil }
    var isPreparing: Bool { preparationTask != nil }
    var audioSeconds: TimeInterval { feed?.audioTime ?? 0 }
    var maximumLevel: Float { feed?.maximumLevel ?? 0 }

    func start(locale: String, phrase: String,
               onWords: @escaping ([SpokenWord], TimeInterval) -> Void,
               onEnd: @escaping (String?) -> Void) throws {
        stop()
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
              recognizer.supportsOnDeviceRecognition else {
            throw CompanionError.message("On-device recognition is unavailable for this language. Enable or download the language in macOS Dictation settings, or choose another language. Hey Voice never falls back to cloud recognition.")
        }
        guard recognizer.isAvailable else { throw CompanionError.message("macOS speech recognition is temporarily unavailable. Try again shortly.") }
        startedAt = ProcessInfo.processInfo.systemUptime
        let token = generation
        Diagnostics.event("languageModelPreparing")
        preparationTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, self.generation == token, self.isPreparing else { return }
            self.stop()
            Diagnostics.event("languageModelTimeout")
            onEnd("On-device wake-phrase setup timed out. Check that the selected Dictation language is installed.")
        }
        preparationTask = Task { [weak self] in
            do {
                let configuration = try await WakeLanguageModel.configuration(locale: locale, phrase: phrase)
                try Task.checkCancellation()
                guard let self, self.generation == token else { return }
                self.preparationTask = nil
                self.preparationTimeout?.cancel(); self.preparationTimeout = nil
                Diagnostics.event("languageModelReady")
                try self.beginCapture(recognizer: recognizer, phrase: phrase, configuration: configuration,
                                      onWords: onWords, onEnd: onEnd)
            } catch {
                guard let self, self.generation == token, !Task.isCancelled else { return }
                Diagnostics.event("languageModelOrCaptureFailed", ["code": (error as NSError).code,
                                                                    "domain": (error as NSError).domain])
                self.stop()
                onEnd("Could not prepare on-device recognition for this wake phrase. Check the selected language and microphone, then try again.")
            }
        }
    }

    private func beginCapture(recognizer: SFSpeechRecognizer, phrase: String,
                              configuration: SFSpeechLanguageModel.Configuration,
                              onWords: @escaping ([SpokenWord], TimeInterval) -> Void,
                              onEnd: @escaping (String?) -> Void) throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.contextualStrings = [phrase]
        request.customizedLanguageModel = configuration
        request.taskHint = .dictation
        let feed = AudioFeed(request)
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CompanionError.message("No microphone is available. Select an input in macOS Sound settings.") }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in feed.append(buffer) }
        self.feed = feed
        self.engine = engine
        self.recognizer = recognizer
        Diagnostics.update(["speechSessionStarted": true, "recognitionResultSeen": false,
                            "recognitionErrorCode": 0, "audioPeak": 0,
                            "wordCount": 0, "containsHey": false, "containsKeyword": false,
                            "lastWordEndsAt": 0, "resultAudioSeconds": 0,
                            "resultFinal": false, "phraseMatched": false, "alternativeCount": 0])
        let token = generation
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.stop()
                onEnd("The microphone configuration changed.")
            }
        }
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let candidates = result?.transcriptions.map { transcription in
                transcription.segments.map { SpokenWord($0.substring, start: $0.timestamp, duration: $0.duration) }
            } ?? []
            let audioTime = feed.audioTime
            let keyword = WakePhrase.normalize(phrase).split(separator: " ").last.map(String.init) ?? ""
            // Speech's best candidate is general dictation, not necessarily the
            // configured wake phrase. Accept an exact match in its alternatives.
            let matchingCandidate = candidates.firstIndex { WakePhrase.matches($0, keyword: keyword, audioTime: audioTime) }
            let words = matchingCandidate.map { candidates[$0] } ?? candidates.first
            let final = result?.isFinal ?? false
            // Do not log transcripts, recognized words, or microphone buffers.
            let failed = error != nil
            let errorCode = (error as NSError?)?.code ?? 0
            let errorDomain = (error as NSError?)?.domain ?? ""
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                if let words {
                    let normalized = WakePhrase.normalize(words.map(\.text).joined(separator: " "))
                    let tokens = normalized.split(separator: " ").map(String.init)
                    let fields: [String: Any] = ["recognitionResultSeen": true, "wordCount": words.count,
                                        "containsHey": tokens.contains("hey"), "containsKeyword": tokens.contains(keyword),
                                        "lastWordEndsAt": words.last.map { $0.start + $0.duration } ?? 0,
                                        "resultAudioSeconds": audioTime, "resultFinal": final,
                                        "alternativeCount": candidates.count, "matchingCandidate": matchingCandidate ?? -1,
                                        "prefixClass": tokens.first == "hey" ? "hey" : tokens.first == "hay" ? "homophone" : tokens.first == "ehi" ? "italianGreeting" : "other"]
                    Diagnostics.update(fields)
                    Diagnostics.event("recognition", fields)
                }
                if failed { Diagnostics.update(["recognitionErrorCode": errorCode, "recognitionErrorDomain": errorDomain]) }
                if let words { onWords(words, audioTime) }
                guard self.generation == token else { return }
                if final || failed {
                    self.stop()
                    onEnd(failed ? "The speech session ended unexpectedly." : nil)
                }
            }
        }
        do { engine.prepare(); try engine.start(); startedAt = ProcessInfo.processInfo.systemUptime }
        catch { stop(); throw CompanionError.message("Could not start the microphone. Check Sound settings and microphone permission.") }
    }

    func stop() {
        generation = UUID()
        preparationTask?.cancel(); preparationTask = nil
        preparationTimeout?.cancel(); preparationTimeout = nil
        if let observer = configurationObserver { NotificationCenter.default.removeObserver(observer) }
        configurationObserver = nil
        if let engine { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        feed?.finish()
        task?.cancel()
        task = nil; feed = nil; engine = nil; recognizer = nil
    }
}

enum CompanionError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}
