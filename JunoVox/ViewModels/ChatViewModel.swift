import Foundation
import AVFoundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    var audioURL: URL? = nil
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var persona: PersonaMode = .Base
    @Published var isLoading = false

    private var player: AVPlayer?

    func sendUserMessage(_ text: String) {
        messages.append(ChatMessage(text: text, isUser: true))
        Task { await fetchJunoReply(for: text) }
    }

    private func fetchJunoReply(for text: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let chatRequest = [ChatMessageDTO(role: "user", content: text)]
            let response = try await JunoAPIClient.shared.chat(messages: chatRequest, personality: persona)
            
            guard let replyText = response.reply else {
                messages.append(ChatMessage(text: "(No reply)", isUser: false))
                return
            }
            
            var junoMessage = ChatMessage(text: replyText, isUser: false)
            messages.append(junoMessage)

            // TTS
            let ttsResp = try await JunoAPIClient.shared.tts(text: replyText)
            if let urlStr = ttsResp.audio_url,
               let url = URL(string: AppConfig.baseURL.absoluteString + urlStr) {
                junoMessage.audioURL = url
                if let idx = messages.firstIndex(where: { $0.id == junoMessage.id }) {
                    messages[idx] = junoMessage
                }
                playAudio(url)
            }

        } catch {
            messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
        }
    }

    private func playAudio(_ url: URL) {
        player = AVPlayer(url: url)
        player?.play()
    }
}