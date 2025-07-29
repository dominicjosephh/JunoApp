import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    // UI
    @Published var messages: [ChatMessage] = []
    @Published var persona: PersonaMode = .Base
    @Published var isLoading = false
    @Published var speakReplies: Bool = true

    // Playback state
    @Published var currentlyPlayingMessageID: UUID? = nil
    @Published var isGlobalPlaying: Bool = false

    // Audio
    private var player: AVPlayer?
    private var timeControlObserver: NSKeyValueObservation?
    private var endObserver: Any?

    var isSpeaking: Bool { player?.timeControlStatus == .playing }

    // MARK: - Init

    init() {
        configureAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Use compatible options for .playback category
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            #if DEBUG
                AudioDiagnostics.logSessionInfo(tag: "AFTER configureAudioSession()")
            #endif
        } catch {
            #if DEBUG
                debugPrint("⚠️ Audio session configuration failed: \(error)")
            #endif
        }
    }

    // MARK: - Public API

    func sendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(text: trimmed, isUser: true))
        Task { await fetchJunoReply(for: trimmed) }
    }

    func toggleGlobalPlayPause() {
        if let player = player {
            if player.timeControlStatus == .playing {
                pause()
            } else {
                player.play()
                isGlobalPlaying = true
            }
        } else {
            if let lastAssistant = messages.last(where: { !$0.isUser && $0.audioURL != nil }),
               let url = lastAssistant.audioURL {
                play(url: url, messageID: lastAssistant.id)
            }
        }
    }

    func togglePlay(for message: ChatMessage) {
        guard let url = message.audioURL else { return }
        if isPlaying(message: message) {
            pause()
            currentlyPlayingMessageID = nil
        } else {
            play(url: url, messageID: message.id)
        }
    }

    func isPlaying(message: ChatMessage) -> Bool {
        currentlyPlayingMessageID == message.id && isSpeaking
    }

    func stopSpeaking() {
        pause()
        currentlyPlayingMessageID = nil
    }

    // MARK: - Networking / TTS

    private func fetchJunoReply(for text: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let chatReq = [ChatMessageDTO(role: "user", content: text)]
            let response = try await JunoAPIClient.shared.chat(messages: chatReq, personality: persona)
            guard let replyText = response.reply, !replyText.isEmpty else {
                messages.append(ChatMessage(text: "(No reply)", isUser: false))
                return
            }

            var junoMsg = ChatMessage(text: replyText, isUser: false)
            messages.append(junoMsg)

            guard speakReplies else { return }

            let ttsResp = try await JunoAPIClient.shared.tts(text: replyText)
            if let urlStr = ttsResp.audio_url {
                // Handle both absolute and relative URLs
                let url: URL
                if urlStr.hasPrefix("http") {
                    guard let absoluteURL = URL(string: urlStr) else {
                        throw APIClientError.badURL
                    }
                    url = absoluteURL
                } else {
                    url = AppConfig.baseURL.appendingPathComponent(urlStr)
                }

                #if DEBUG
                    debugPrint("🔗 TTS URL: \(url.absoluteString)")
                #endif

                if let idx = messages.firstIndex(where: { $0.id == junoMsg.id }) {
                    junoMsg.audioURL = url
                    messages[idx] = junoMsg
                }
                play(url: url, messageID: junoMsg.id)
            }
        } catch {
            messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
        }
    }

    // MARK: - Playback

    private func play(url: URL, messageID: UUID) {
        pause() // stop any active playback

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        currentlyPlayingMessageID = messageID

        #if DEBUG
            AudioDiagnostics.logSessionInfo(tag: "BEFORE player.play()")
        #endif

        // Observe timeControlStatus to catch instant failures
        timeControlObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self = self else { return }
            #if DEBUG
                debugPrint("🎧 AVPlayer timeControlStatus: \(player.timeControlStatus.rawValue)")
            #endif
        }

        // Observe completion
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.pause()
                self.currentlyPlayingMessageID = nil
            }
        }

        player?.play()
        isGlobalPlaying = true

        #if DEBUG
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                AudioDiagnostics.logSessionInfo(tag: "AFTER player.play()")
                if let err = item.error {
                    debugPrint("❌ Player item error: \(err.localizedDescription)")
                }
                debugPrint("⏱️ Player rate: \(self.player?.rate ?? -1)")
            }
        #endif
    }

    private func pause() {
        player?.pause()
        player = nil
        isGlobalPlaying = false
        timeControlObserver = nil
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    deinit {
        timeControlObserver = nil
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}

// MARK: - ChatMessage model (keep near ChatViewModel for clarity)

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    var audioURL: URL? = nil
}
