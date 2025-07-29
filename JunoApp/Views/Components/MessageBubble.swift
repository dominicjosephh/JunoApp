import SwiftUI

struct MessageBubble: View {
    @EnvironmentObject var viewModel: ChatViewModel
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

                if !message.isUser, let _ = message.audioURL {
                    Button {
                        viewModel.togglePlay(for: message)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isPlaying(message: message)
                                  ? "pause.circle.fill"
                                  : "play.circle.fill")
                            Text(viewModel.isPlaying(message: message) ? "Pause" : "Play")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
            }

            if !message.isUser { Spacer() }
        }
        .padding(.horizontal)
    }
}
