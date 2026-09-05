// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeyVoice",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "HeyVoice", targets: ["HeyVoice"])],
    targets: [
        .target(name: "HeyVoiceCore"),
        .executableTarget(name: "HeyVoice", dependencies: ["HeyVoiceCore"]),
        .testTarget(name: "HeyVoiceCoreTests", dependencies: ["HeyVoiceCore"])
    ],
    swiftLanguageModes: [.v5]
)
