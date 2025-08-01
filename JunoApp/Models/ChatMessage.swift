import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let audioURL: URL?
    
    init(text: String, isUser: Bool, audioURL: URL? = nil) {
        self.text = text
        self.isUser = isUser
        self.audioURL = audioURL
    }
}

// Helper functions to create messages
func userMessage(_ text: String) -> ChatMessage {
    return ChatMessage(text: text, isUser: true)
}

func assistantMessage(_ text: String, audioURL: URL? = nil) -> ChatMessage {
    return ChatMessage(text: text, isUser: false, audioURL: audioURL)
}
