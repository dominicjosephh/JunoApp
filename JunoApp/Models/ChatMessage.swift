import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    var audioURL: URL?
    var isPlaying: Bool = false
    
    static func userMessage(_ text: String) -> ChatMessage {
        ChatMessage(text: text, isUser: true)
    }
    
    static func assistantMessage(_ text: String, audioURL: URL? = nil) -> ChatMessage {
        ChatMessage(text: text, isUser: false, audioURL: audioURL)
    }
}
