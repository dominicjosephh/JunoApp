import SwiftUI

struct VoiceRecordingIndicator: View {
    let audioLevel: Float
    let isRecording: Bool
    
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 12) {
            // Recording icon with pulse animation
            Image(systemName: "mic.fill")
                .font(.system(size: 16))
                .foregroundColor(.red)
                .scaleEffect(pulseScale)
                .animation(
                    isRecording ? 
                    Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : 
                    .default,
                    value: pulseScale
                )
                .onAppear {
                    if isRecording {
                        pulseScale = 1.3
                    }
                }
                .onChange(of: isRecording) { recording in
                    pulseScale = recording ? 1.3 : 1.0
                }
            
            // Audio level visualization
            VStack(spacing: 2) {
                Text("Recording...")
                    .font(.caption)
                    .foregroundColor(.red)
                
                // Audio level bars
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(audioLevelColor(for: index))
                            .frame(width: 3, height: audioLevelHeight(for: index))
                            .animation(.easeInOut(duration: 0.1), value: audioLevel)
                    }
                }
            }
            
            Spacer()
            
            Text("Tap mic again to stop")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func audioLevelColor(for index: Int) -> Color {
        let threshold = Float(index) / 5.0
        return audioLevel > threshold ? .red : .gray.opacity(0.3)
    }
    
    private func audioLevelHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 12
        let threshold = Float(index) / 5.0
        
        if audioLevel > threshold {
            let intensity = min(audioLevel * 2, 1.0) // Amplify the visual effect
            return baseHeight + (maxHeight - baseHeight) * CGFloat(intensity)
        } else {
            return baseHeight
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        VoiceRecordingIndicator(audioLevel: 0.0, isRecording: true)
        VoiceRecordingIndicator(audioLevel: 0.3, isRecording: true)
        VoiceRecordingIndicator(audioLevel: 0.7, isRecording: true)
        VoiceRecordingIndicator(audioLevel: 1.0, isRecording: true)
    }
    .padding()
}