import SwiftUI
import AVFoundation

struct ConversationView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConversationViewModel()
    
    var body: some View {
        VStack {
            header
            Divider()
            transcriptList
            Spacer()
            recordControl
                .padding(.vertical, 24)
        }
        .padding(.horizontal)
        .onAppear {
            Task { try? await AudioSessionManager.shared.configureForVoice() }
        }
        .alert(isPresented: $viewModel.showingError) {
            Alert(title: Text("Error"),
                  message: Text(viewModel.lastErrorMessage ?? "Unknown error"),
                  dismissButton: .default(Text("OK")))
        }
    }
    
    private var header: some View {
        HStack {
            Text("Conversation")
                .font(.title2).bold()
            Spacer()
            if let adapted = viewModel.lastAdaptedMode {
                Text("Mode: \(adapted)")
                    .font(.subheadline)
                    .padding(6)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
            } else {
                Text("Mode: \(appState.persona.rawValue)")
                    .font(.subheadline)
                    .padding(6)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding(.top)
    }
    
    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.turns) { turn in
                        if let user = turn.userText {
                            bubble(text: user, isUser: true)
                        }
                        if let juno = turn.junoText {
                            bubble(text: juno, isUser: false,
                                   emotion: turn.detectedEmotion,
                                   mode: turn.adaptedMode)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.turns.count) { _ in
                withAnimation {
                    if let last = viewModel.turns.last?.id {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func bubble(text: String, isUser: Bool,
                        emotion: String? = nil,
                        mode: String? = nil) -> some View {
        HStack {
            if isUser { Spacer() }
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .padding(10)
                    .background(isUser ? Color.blue.opacity(0.8)
                                        : Color.gray.opacity(0.3))
                    .foregroundColor(isUser ? .white : .black)
                    .cornerRadius(12)
                
                if !isUser {
                    HStack(spacing: 6) {
                        if let emotion = emotion {
                            badge("emotion: \(emotion)")
                        }
                        if let mode = mode {
                            badge("mode: \(mode)")
                        }
                    }
                }
            }
            if !isUser { Spacer() }
        }
        .padding(.horizontal)
    }
    
    private func badge(_ txt: String) -> some View {
        Text(txt)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.08))
            .cornerRadius(6)
    }
    
    private var recordControl: some View {
        VStack(spacing: 12) {
            Text(viewModel.uiStateText)
                .font(.footnote)
                .foregroundColor(.secondary)
            Button(action: {
                Haptic.tap()
                Task {
                    if viewModel.isRecording {
                        await viewModel.stopAndSend(persona: appState.persona)
                    } else {
                        await viewModel.startRecording()
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.blue)
                        .frame(width: 82, height: 82)
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 32, weight: .bold))
                }
            }
        }
    }
}

enum Haptic {
    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}