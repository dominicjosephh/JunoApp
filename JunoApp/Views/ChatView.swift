import SwiftUI
import AVFoundation

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Juno Chat")
                    .font(.title2).bold()
                Spacer()
                Picker("Persona", selection: $viewModel.persona) {
                    ForEach(PersonaMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.messages) { msg in
                            MessageBubble(message: msg)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    withAnimation {
                        if let lastID = viewModel.messages.last?.id {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            // Input field
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading)
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .padding(.trailing)
                }
                .disabled(messageText.isEmpty || viewModel.isLoading)
            }
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Juno is thinking…")
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.sendUserMessage(text)
        messageText = ""
    }
}