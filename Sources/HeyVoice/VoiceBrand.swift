import AppKit

enum VoiceBrand {
    static func icon(size: CGFloat) -> NSImage {
        let artwork = Bundle.main.url(forResource: "VoiceOrb", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
        let image = artwork ?? NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Hey Voice")!
        image.size = NSSize(width: size, height: size)
        image.isTemplate = false
        image.accessibilityDescription = "Hey Voice"
        return image
    }
}
