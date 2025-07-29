import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()
    private init() {}

    func configureForVoice() async throws {
        let session = AVAudioSession.sharedInstance()
        
        print("🎤 Configuring audio session for voice...")

        do {
            // Use a more compatible configuration for voice recording
            try session.setCategory(.playAndRecord,
                                    mode: .default, // Changed from voiceChat for better compatibility
                                    options: [.allowBluetooth, .defaultToSpeaker])
            
            print("🎤 Category set to: \(session.category.rawValue), mode: \(session.mode.rawValue)")

            // Set active with proper options
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("🎤 Session activated successfully")

            // Make sure we're using the speaker for output
            try session.overrideOutputAudioPort(.speaker)
            print("🎤 Output port overridden to speaker")
            
            #if DEBUG
                AudioDiagnostics.logSessionInfo(tag: "Voice Session Configured")
            #endif

        } catch let error as NSError {
            // Better error logging
            print("❌ Audio session configuration failed: \(error.localizedDescription), code: \(error.code)")
            throw error
        }
    }

    func configureForPlayback() async throws {
        let session = AVAudioSession.sharedInstance()
        
        print("🔊 Configuring audio session for playback...")

        do {
            // Simpler playback-only configuration - using .playback for better compatibility
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            print("🔊 Category set to: \(session.category.rawValue), mode: \(session.mode.rawValue)")
            
            try session.setActive(true)
            print("🔊 Session activated successfully")
            
            #if DEBUG
                AudioDiagnostics.logSessionInfo(tag: "Playback Session Configured")
            #endif

        } catch let error as NSError {
            print("❌ Audio playback configuration failed: \(error.localizedDescription), code: \(error.code)")
            throw error
        }
    }
    
    // Debug method to check audio session status
    func debugStatus() -> String {
        let session = AVAudioSession.sharedInstance()
        var status = "--- Audio Session Status ---\n"
        status += "Category: \(session.category.rawValue)\n"
        status += "Mode: \(session.mode.rawValue)\n"
        status += "Active: \(session.isOtherAudioPlaying ? "Yes" : "No")\n"
        status += "Sample rate: \(session.sampleRate)\n"
        
        let outputs = session.currentRoute.outputs.map {
            "\($0.portType.rawValue)(\($0.portName))"
        }.joined(separator: ", ")
        status += "Route: \(outputs)\n"
        
        return status
    }
}
