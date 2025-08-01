import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    
    var body: some View {
        VStack {
            // Messages list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .environmentObject(viewModel)
                    }
                }
                .padding()
            }
            
            // Input field
            HStack {
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                }
                .disabled(inputText.isEmpty)
            }
            .padding()
        }
        .overlay(
            // Error banner
            Group {
                if let error = viewModel.error {
                    VStack {
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                            .padding()
                        Spacer()
                    }
                }
            }
        )
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        viewModel.sendMessage(text)
        inputText = ""
    }
}
