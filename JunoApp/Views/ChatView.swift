import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText: String = ""

    @available(iOS 15.6, *)
    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header
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

                Button {
                    viewModel.toggleGlobalPlayPause()
                } label: {
                    Image(systemName: viewModel.isGlobalPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                }
                .padding(.leading, 8)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            Divider()

            // MARK: - Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastID = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
            Divider()

            // MARK: - Input
            Divider()
            HStack {
                if #available(iOS 16.0, *) {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                } else {
                    TextField("Type a message...", text: $messageText)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                }
                .padding(.leading, 6)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.gray.opacity(0.05))
        
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
