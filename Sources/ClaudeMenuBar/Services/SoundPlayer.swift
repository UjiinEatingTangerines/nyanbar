import AppKit

/// Plays notification sounds using macOS system sounds.
struct SoundPlayer {
    /// Play a short "meow" notification sound
    static func playMeow() {
        // Use system sound — "Purr" is cat-appropriate, fallback to "Glass"
        let soundNames = ["Purr", "Pop", "Glass"]
        for name in soundNames {
            if let sound = NSSound(named: NSSound.Name(name)) {
                sound.play()
                return
            }
        }
        // Last resort: system beep
        NSSound.beep()
    }
}
