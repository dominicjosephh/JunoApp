import Foundation
import AVFoundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isPlaying: Bool = false
    @Published var currentlyPlayingId: UUID?
    @Published var error: String?
    
    private var audioPlayer: AVPlayer?
    private var playerObserver: Any?
    private let apiClient = JunoAPIClient()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize with a welcome message
        messages.append(assistantMessage("Hello! I'm Juno. How can I help you today?"))
    }
    
    func sendMessage(_ text: String) {
        // Add user message
        messages.append(userMessage(text))
        
        // Get AI response
        Task {
            do {
                // Configure audio session for playback
                try AudioSessionManager.shared.configureForPlayback()
                
                let response = try await apiClient.chat(messages: [
                    ["role": "user", "content": text]
                ])
                
                // Add assistant message
                if let reply = response["reply"] as? String {
                    messages.append(assistantMessage(reply))
                    
                    // Get TTS audio
                    if !reply.isEmpty {
                        await getTTSAndPlay(for: reply)
                    }
                }
            } catch {
                showError("Failed to send message: \(error.localizedDescription)")
            }
        }
    }
    
    private func getTTSAndPlay(for text: String) async {
        do {
            let ttsResponse = try await apiClient.textToSpeech(text: text)
            
            if let audioURLString = ttsResponse["audio_url"] as? String {
                // Update last message with audio URL
                if let lastMessage = messages.last {
                    let audioURL = apiClient.buildAudioURL(from: audioURLString)
                    messages[messages.count - 1] = ChatMessage(
                        text: lastMessage.text,
                        isUser: lastMessage.isUser,
                        audioURL: audioURL
                    )
                    
                    // Play audio
                    if let url = audioURL {
                        playAudio(from: url, messageId: lastMessage.id)
                    }
                }
            }
        } catch {
            showError("TTS failed: \(error.localizedDescription)")
        }
    }
    
    func playAudio(from url: URL, messageId: UUID) {
        // Stop any currently playing audio
        stopAudio()
        
        // Create player item
        let playerItem = AVPlayerItem(url: url)
        
        // Add observer for when audio finishes
        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.audioDidFinishPlaying()
            }
        }
        
        // Create and configure player
        audioPlayer = AVPlayer(playerItem: playerItem)
        audioPlayer?.play()
        
        // Update UI state
        isPlaying = true
        currentlyPlayingId = messageId
        
        // Log for debugging
        #if DEBUG
            AudioDiagnostics.logPlayerStatus(player: audioPlayer, tag: "ChatViewModel playAudio")
        #endif
    }
    
    func stopAudio() {
        audioPlayer?.pause()
        audioPlayer = nil
        
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
            playerObserver = nil
        }
        
        isPlaying = false
        currentlyPlayingId = nil
    }
    
    private func audioDidFinishPlaying() {
        isPlaying = false
        currentlyPlayingId = nil
    }
    
    func togglePlay(for message: ChatMessage) {
        if currentlyPlayingId == message.id && isPlaying {
            stopAudio()
        } else if let audioURL = message.audioURL {
            playAudio(from: audioURL, messageId: message.id)
        }
    }
    
    func isPlaying(message: ChatMessage) -> Bool {
        return currentlyPlayingId == message.id && isPlaying
    }
    
    private func showError(_ message: String) {
        self.error = message
        // Clear error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.error = nil
        }
    }
    
    deinit {
        Task { @MainActor in
            self.stopAudio()
        }
    }
}
