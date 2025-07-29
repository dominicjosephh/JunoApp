import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()
    private init() {}

    func configureForVoice() async throws {
        let session = AVAudioSession.sharedInstance()

        do {
            // Use a more compatible configuration for voice recording
            try session.setCategory(.playAndRecord,
                                    mode: .voiceChat,
                                    options: [.allowBluetooth, .allowBluetoothA2DP])

            // Set active with proper options
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            // If you need speaker output, set it after the session is active
            if session.category == .playAndRecord {
                try session.overrideOutputAudioPort(.speaker)
            }

        } catch let error as NSError {
            // Better error logging
            print("Audio session configuration failed: \(error.localizedDescription), code: \(error.code)")
            throw error
        }
    }

    func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()

        do {
            // Simpler playback-only configuration
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)

        } catch let error as NSError {
            print("Audio playback configuration failed: \(error.localizedDescription), code: \(error.code)")
            throw error
        }
    }
}
