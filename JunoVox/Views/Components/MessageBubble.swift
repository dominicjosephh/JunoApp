import SwiftUI
import AVFoundation

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .padding(10)
                    .background(message.isUser ? Color.blue.opacity(0.8)
                                               : Color.gray.opacity(0.3))
                    .foregroundColor(message.isUser ? .white : .black)
                    .cornerRadius(12)
                if let audioURL = message.audioURL {
                    Button(action: { playAudio(url: audioURL) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2.fill")
                            Text("Play")
                        }
                        .font(.caption)
                        .padding(6)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            if !message.isUser { Spacer() }
        }
        .padding(.horizontal)
    }

    private func playAudio(url: URL) {
        let player = AVPlayer(url: url)
        player.play()
    }
}