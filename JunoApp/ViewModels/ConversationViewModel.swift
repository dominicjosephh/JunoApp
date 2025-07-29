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

            let voiceResp = try await JunoAPIClient.shared.processVoice(
                audioData: data,
                filename: "voice.m4a",
                mimeType: "audio/m4a",
                voiceMode: persona
            )

            var turn = ConversationTurn()
            turn.userText = "🎤 (voice sent)" // Replace with transcript when backend returns it

            if let reply = voiceResp.reply {
                turn.junoText = reply
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
                let tts = try await JunoAPIClient.shared.tts(text: reply)
                if let path = tts.audio_url,
                   let url = URL(string: AppConfig.baseURL.appendingPathComponent(path).absoluteString) {
                    play(url)
                }
            }

            uiStateText = "Tap to talk"
        } catch {
            showError(error.localizedDescription)
            uiStateText = "Tap to talk"
        }
    }

    private func play(_ url: URL) {
        #if DEBUG
            print("🎵 AVPlayer URL:", url.absoluteString)
        #endif

        let item = AVPlayerItem(url: url)

        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        // Add observers for debugging
        player?.addObserver(self as! NSObject, forKeyPath: "status", options: [.new, .old], context: nil)
        player?.addObserver(self as! NSObject, forKeyPath: "timeControlStatus", options: [.new, .old], context: nil)

        player?.play()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let player = object as? AVPlayer {
                switch player.status {
                case .readyToPlay:
                    print("🎧 AVPlayer is ready to play")
                case .failed:
                    print("❌ AVPlayer failed with error: \(String(describing: player.error))")
                case .unknown:
                    print("⚠️ AVPlayer status is unknown")
                @unknown default:
                    break
                }
            }
        } else if keyPath == "timeControlStatus" {
            if let player = object as? AVPlayer {
                switch player.timeControlStatus {
                case .playing:
                    print("🎶 AVPlayer is playing")
                case .paused:
                    print("⏸️ AVPlayer is paused")
                case .waitingToPlayAtSpecifiedRate:
                    print("⏳ AVPlayer is waiting to play")
                @unknown default:
                    break
                }
            }
        }
    }

    private func showError(_ msg: String) {
        lastErrorMessage = msg
        showingError = true
    }
}
