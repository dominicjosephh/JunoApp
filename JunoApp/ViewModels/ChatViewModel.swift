import AVFoundation
import Foundation

struct ConversationTurn: Identifiable {
    let id = UUID()
    var userText: String?
    var junoText: String?
    var detectedEmotion: String?
    var adaptedMode: String?
}

@MainActor
final class ConversationViewModel: ObservableObject {
    @Published var turns: [ConversationTurn] = []
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
            try await AudioSessionManager.shared.configureForVoice()
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
            guard let data = recorder.stop() else {
                showError("No audio data captured.")
                uiStateText = "Tap to talk"
                return
            }
            
            print("📊 Audio data size: \(data.count) bytes")

            let voiceResp = try await JunoAPIClient.shared.processVoice(
                audioData: data,
                filename: "voice.m4a",
                mimeType: "audio/m4a",
                voiceMode: persona
            )
            
            print("📥 Voice response received: \(voiceResp.reply ?? "nil")")

            var turn = ConversationTurn()
            turn.userText = "🎤 (voice sent)" // Replace with transcript when backend returns it

            if let reply = voiceResp.reply {
                turn.junoText = reply
                lastResponse = reply
            } else {
                turn.junoText = "(No reply)"
            }

            if let emo = voiceResp.emotion_data?.emotion {
                turn.detectedEmotion = emo
            }
            if let adapted = voiceResp.adapted_voice_mode {
                turn.adaptedMode = adapted
                lastAdaptedMode = adapted
            } else if let serverMode = voiceResp.voice_mode {
                lastAdaptedMode = serverMode
            }

            turns.append(turn)

            // TTS
            if let reply = voiceResp.reply {
                print("🎯 Getting TTS for: \(String(reply.prefix(20)))...")
                
                let ttsResp = try await JunoAPIClient.shared.tts(text: reply)
                print("🔊 TTS response received: \(ttsResp)")
                
                if let urlStr = ttsResp.audio_url {
                    print("🔗 Raw audio URL: \(urlStr)")
                    
                    let url: URL
                    if urlStr.hasPrefix("http") {
                        guard let absoluteURL = URL(string: urlStr) else {
                            print("⚠️ Invalid absolute URL: \(urlStr)")
                            throw APIClientError.badURL
                        }
                        url = absoluteURL
                    } else {
                        url = AppConfig.baseURL.appendingPathComponent(urlStr)
                    }
                    
                    print("🎵 Final audio URL: \(url.absoluteString)")
                    self.audioUrl = url
                    
                    // Test if the URL is accessible
                    let request = URLRequest(url: url)
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse {
                        print("🧪 URL test status code: \(httpResponse.statusCode)")
                        if httpResponse.statusCode != 200 {
                            print("⚠️ Audio URL returned non-200 status: \(httpResponse.statusCode)")
                        }
                    }
                    
                    // Configure audio session before playing
                    try await AudioSessionManager.shared.configureForPlayback()
                    
                    await MainActor.run {
                        self.playAudio(url)
                    }
                } else {
                    print("⚠️ No audio URL in TTS response")
                }
            }

            uiStateText = "Tap to talk"
        } catch {
            print("❌ Error processing voice: \(error)")
            showError(error.localizedDescription)
            uiStateText = "Tap to talk"
        }
    }

    @MainActor
    private func playAudio(_ url: URL) {
        print("▶️ Starting audio playback for URL: \(url.absoluteString)")
        
        // Clean up previous observers
        cleanupObservers()
        
        let item = AVPlayerItem(url: url)
        print("📝 Created AVPlayerItem for URL: \(url.lastPathComponent)")

        if player == nil {
            player = AVPlayer(playerItem: item)
            print("🆕 Created new AVPlayer instance")
        } else {
            player?.replaceCurrentItem(with: item)
            print("♻️ Replaced AVPlayer item")
        }
        
        // Debug check item properties
        print("🔍 Player item duration: \(item.duration.seconds)")
        print("🔍 Player item status: \(item.status.rawValue)")
        
        // Set up observers with modern KVO API
        statusObserver = item.observe(\.status, options: [.new]) { item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    print("✅ AVPlayer is ready to play")
                case .failed:
                    print("❌ AVPlayer failed with error: \(String(describing: item.error))")
                    if let error = item.error {
                        self.showError("Audio playback error: \(error.localizedDescription)")
                    }
                case .unknown:
                    print("⚠️ AVPlayer status is unknown")
                @unknown default:
                    break
                }
            }
        }
        
        timeControlStatusObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                print("🎮 Player timeControlStatus changed to: \(player.timeControlStatus.rawValue)")
                switch player.timeControlStatus {
                case .playing:
                    print("🎶 AVPlayer is playing")
                    self?.uiStateText = "Playing audio..."
                case .paused:
                    print("⏸️ AVPlayer is paused")
                case .waitingToPlayAtSpecifiedRate:
                    let reason = player.reasonForWaitingToPlay?.rawValue ?? "unknown"
                    print("⏳ AVPlayer is waiting to play. Reason: \(reason)")
                @unknown default:
                    break
                }
            }
        }
        
        // Add notification for when playback ends - must be on main actor
        endTimeObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            print("✅ Audio playback completed")
            Task { @MainActor in
                self?.uiStateText = "Tap to talk"
                self?.cleanupObservers()
            }
        }

        print("▶️ Playing audio...")
        player?.play()
    }
    
    @MainActor
    private func cleanupObservers() {
        print("🧹 Cleaning up player observers")
        statusObserver = nil
        timeControlStatusObserver = nil
        
        if let observer = endTimeObserver {
            NotificationCenter.default.removeObserver(observer)
            endTimeObserver = nil
        }
    }

    private func showError(_ msg: String) {
        print("❌ Error: \(msg)")
        lastErrorMessage = msg
        showingError = true
    }
    
    deinit {
        cleanupObservers()
    }
    
    // Debug methods
    func debugInfo() -> String {
        var info = "--- Debug Info ---\n"
        info += "Last URL: \(audioUrl?.absoluteString ?? "none")\n"
        info += "Last Response: \(lastResponse?.prefix(50) ?? "none")\n"
        info += "Audio Session Category: \(AVAudioSession.sharedInstance().category.rawValue)\n"
        info += "Audio Session Active: \(try? AVAudioSession.sharedInstance().isOtherAudioPlaying)\n"
        return info
    }
}
