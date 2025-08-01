import AVFoundation
import Foundation

// Renamed to VoiceConversationTurn to avoid conflicts with other types
struct VoiceConversationTurn: Identifiable {
    let id = UUID()
    var userText: String?
    var junoText: String?
    var detectedEmotion: String?
    var adaptedMode: String?
}

@MainActor
final class ConversationViewModel: ObservableObject {
    @Published var turns: [VoiceConversationTurn] = []
    
    @Published var isRecording: Bool = false
    @Published var uiStateText: String = "Tap to talk"
    
    @Published var lastAdaptedMode: String?
    
    @Published var showingError: Bool = false
    @Published var lastErrorMessage: String?
    
    private let recorder = AudioRecorder()
    private var player: AVPlayer?
    private var statusObserver: NSKeyValueObservation?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var endTimeObserver: Any?
    
    // Debug properties
    private var audioUrl: URL?
    private var lastResponse: String?
    
    func startRecording() async {
        do {
            try AudioSessionManager.shared.configureForVoice()
            try recorder.start()
            isRecording = true
            uiStateText = "Listening… tap to stop"
        } catch {
            showError("Mic error: \(error.localizedDescription)")
        }
    }
    
    func stopAndSend(persona: PersonaMode) async {
        isRecording = false
        uiStateText = "Processing…"
        
        do {
            guard let audioData = recorder.stop() else {
                showError("No audio data captured.")
                uiStateText = "Tap to talk"
                return
            }
            
            print("🎤 Audio data captured: \(audioData.count) bytes")
            
            // Process voice with backend
            let apiClient = JunoAPIClient()
            print("🌐 Sending voice to backend with mode: \(persona.rawValue)")
            
            let voiceResp = try await apiClient.processVoice(
                audioData: audioData,
                filename: "voice.m4a",
                mimeType: "audio/m4a",
                voiceMode: persona.rawValue
            )
            
            print("✅ Backend response received: \(voiceResp)")
            
            // Create conversation turn
            var turn = VoiceConversationTurn()
            
            // Add user transcription if available
            if let transcription = voiceResp["transcription"] as? String {
                turn.userText = transcription
            } else {
                turn.userText = "🎤 (voice sent)"
            }
            
            // Add Juno's response (backend returns "reply", not "response")
            if let reply = voiceResp["reply"] as? String {
                turn.junoText = reply
            } else {
                turn.junoText = "(No reply)"
            }
            
            // Add emotion data if available
            if let emotionData = voiceResp["emotion_data"] as? [String: Any],
               let emotion = emotionData["emotion"] as? String {
                turn.detectedEmotion = emotion
            }
            
            // Handle adapted voice mode
            if let adapted = voiceResp["adapted_voice_mode"] as? String {
                turn.adaptedMode = adapted
                lastAdaptedMode = adapted
            } else if let serverMode = voiceResp["voice_mode"] as? String {
                lastAdaptedMode = serverMode
            }
            
            turns.append(turn)
            
            // Generate and play TTS if we have a response
            if let reply = voiceResp["reply"] as? String, !reply.isEmpty {
                do {
                    let ttsResp = try await apiClient.textToSpeech(text: reply, voiceMode: persona.rawValue)
                    if let urlStr = ttsResp["audio_url"] as? String {
                        if let url = apiClient.buildAudioURL(from: urlStr) {
                            self.audioUrl = url
                            print("🔗 TTS URL: \(url)")
                            #if DEBUG
                                AudioDiagnostics.logURLRequest(url: url, tag: "Voice Response TTS")
                            #endif
                            play(url)
                        } else {
                            showError("Invalid TTS URL: \(urlStr)")
                        }
                    } else {
                        print("⚠️ No audio URL in TTS response")
                    }
                } catch {
                    print("❌ TTS request failed: \(error)")
                    #if DEBUG
                        AudioDiagnostics.logAudioPlaybackError(error: error, context: "ConversationViewModel TTS")
                    #endif
                    showError("TTS failed: \(error.localizedDescription)")
                }
            }
            
            uiStateText = "Tap to talk"
        } catch {
            print("❌ Voice processing error: \(error)")
            print("❌ Error description: \(error.localizedDescription)")
            if let apiError = error as? APIClientError {
                print("❌ API Client Error: \(apiError)")
            }
            showError("Voice processing failed: \(error.localizedDescription)")
            uiStateText = "Tap to talk"
        }
    }
    
    func play(_ url: URL) {
        print("▶️ Attempting to play audio from URL: \(url)")
        
        #if DEBUG
            AudioDiagnostics.logURLRequest(url: url, tag: "TTS Playback Request")
        #endif
        
        // Configure audio session for playback
        do {
            try AudioSessionManager.shared.configureForPlayback()
        } catch {
            print("❌ Audio session configuration failed: \(error)")
            #if DEBUG
                AudioDiagnostics.logAudioPlaybackError(error: error, context: "ConversationViewModel session config")
            #endif
            showError("Audio session error: \(error.localizedDescription)")
            return
        }
        
        // Clean up previous player and observers
        if let existingPlayer = player {
            existingPlayer.pause()
            statusObserver?.invalidate()
            timeControlStatusObserver?.invalidate()
            if let observer = endTimeObserver {
                existingPlayer.removeTimeObserver(observer)
            }
        }
        
        // Create new player
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        self.player = newPlayer
        
        // Add observers for debugging
        statusObserver = newPlayer.observe(\.status, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self = self else { return }
                switch player.status {
                case .readyToPlay:
                    print("🎧 AVPlayer is ready to play")
                case .failed:
                    if let error = player.error {
                        print("❌ AVPlayer failed with error: \(error)")
                        self.showError("Playback error: \(error.localizedDescription)")
                    }
                case .unknown:
                    print("⚠️ AVPlayer status is unknown")
                @unknown default:
                    break
                }
            }
        }
        
        timeControlStatusObserver = newPlayer.observe(\.timeControlStatus, options: [.new]) { player, _ in
            Task { @MainActor in
                print("🎧 AVPlayer timeControlStatus: \(player.timeControlStatus.rawValue)")
                switch player.timeControlStatus {
                case .playing:
                    print("🎶 AVPlayer is playing at rate: \(player.rate)")
                case .paused:
                    print("⏸️ AVPlayer is paused")
                case .waitingToPlayAtSpecifiedRate:
                    if let reason = player.reasonForWaitingToPlay {
                        print("⏳ AVPlayer is waiting to play because: \(reason)")
                    }
                @unknown default:
                    break
                }
            }
        }
        
        // Observe player item for errors
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("❌ AVPlayerItem failed to play: \(error)")
            }
        }
        
        // Add end time observer
        endTimeObserver = newPlayer.addBoundaryTimeObserver(
            forTimes: [NSValue(time: playerItem.duration)],
            queue: .main
        ) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                print("✅ Audio playback completed")
                self.player = nil
            }
        }
        
        // Start playback
        newPlayer.play()
        print("▶️ Started playing audio")
        
        #if DEBUG
            AudioDiagnostics.logPlayerStatus(player: newPlayer, tag: "After play() call")
        #endif
    }
    
    private func showError(_ message: String) {
        lastErrorMessage = message
        showingError = true
        print("❌ Error: \(message)")
    }
    
    deinit {
        // Clean up observers
        statusObserver?.invalidate()
        timeControlStatusObserver?.invalidate()
        if let observer = endTimeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
}
