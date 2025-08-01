import AVFoundation

class AudioSessionManager {
    static let shared = AudioSessionManager()
    private let audioSession = AVAudioSession.sharedInstance()
    
    private init() {}
    
    func configureForPlayback() throws {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [])
            try audioSession.setActive(true)
            print("✅ Audio session configured for playback")
        } catch {
            print("❌ Audio session configuration error: \(error)")
            throw error
        }
    }
    
    func configureForRecording() throws {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            print("✅ Audio session configured for recording")
        } catch {
            print("❌ Audio session configuration error: \(error)")
            throw error
        }
    }
    
    func configureForVoice() throws {
        // configureForVoice is equivalent to configureForRecording for voice interactions
        try configureForRecording()
    }
    
    func debugStatus() -> String {
        let session = audioSession
        return """
        Category: \(session.category.rawValue)
        Mode: \(session.mode.rawValue)
        Active: \(session.isOtherAudioPlaying ? "Yes" : "No")
        Sample Rate: \(session.sampleRate)
        IO Buffer Duration: \(session.ioBufferDuration)
        """
    }
    
    func deactivate() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated")
        } catch {
            print("❌ Audio session deactivation error: \(error)")
        }
    }
}
