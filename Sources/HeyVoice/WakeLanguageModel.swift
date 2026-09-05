import CryptoKit
import Foundation
import Speech

/// Builds from the configured text only, never from microphone recordings.
/// A shared preparation task avoids recompilation when listening is paused.
@MainActor
enum WakeLanguageModel {
    private static var pending: [String: Task<SFSpeechLanguageModel.Configuration, Error>] = [:]

    static func configuration(locale: String, phrase: String) async throws -> SFSpeechLanguageModel.Configuration {
        let seed = "v1|\(ProcessInfo.processInfo.operatingSystemVersionString)|\(locale)|\(phrase)"
        let key = SHA256.hash(data: Data(seed.utf8)).map { String(format: "%02x", $0) }.joined()
        if let task = pending[key] { return try await task.value }
        let task = Task<SFSpeechLanguageModel.Configuration, Error> {
            let root = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
                .appendingPathComponent("io.github.heyvoice.companion/WakeModels/\(key)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let training = root.appendingPathComponent("phrases.bin")
            let configuration = SFSpeechLanguageModel.Configuration(
                languageModel: root.appendingPathComponent("language-model.bin"),
                vocabulary: root.appendingPathComponent("vocabulary.bin"))
            if !FileManager.default.fileExists(atPath: training.path) {
                let data = SFCustomLanguageModelData(locale: Locale(identifier: locale),
                                                     identifier: "io.github.heyvoice.companion.\(key)", version: "1")
                data.insert(phraseCount: .init(phrase: phrase, count: 100))
                try await data.export(to: training)
            }
            #if compiler(>=6.2)
            if #available(macOS 26, *) {
                try await SFSpeechLanguageModel.prepareCustomLanguageModel(for: training, configuration: configuration)
            } else {
                try await SFSpeechLanguageModel.prepareCustomLanguageModel(for: training,
                    clientIdentifier: "io.github.heyvoice.companion", configuration: configuration)
            }
            #else
            try await SFSpeechLanguageModel.prepareCustomLanguageModel(for: training,
                clientIdentifier: "io.github.heyvoice.companion", configuration: configuration)
            #endif
            return configuration
        }
        // Only a few user selections need to stay in memory. Disk data is an OS cache.
        if pending.count >= 4 { pending.removeAll() }
        pending[key] = task
        do { return try await task.value }
        catch { pending[key] = nil; throw error }
    }
}
