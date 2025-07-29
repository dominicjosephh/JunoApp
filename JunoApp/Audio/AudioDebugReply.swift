import SwiftUI
import AVFoundation

struct AudioDebugView: View {
    @State private var audioSessionInfo = "No data"
    @State private var testAudioStatus = "Not tested"
    @State private var showingLogs = false
    
    let testAudioUrl = URL(string: "https://www2.cs.uic.edu/~i101/SoundFiles/BabyElephantWalk60.wav")!
    @State private var player: AVPlayer?
    
    var body: some View {
        Form {
            Section(header: Text("Audio Session Status")) {
                Text(audioSessionInfo)
                    .font(.system(.caption, design: .monospaced))
                
                Button("Refresh Status") {
                    refreshAudioStatus()
                }
            }
            
            Section(header: Text("Test Audio Playback")) {
                Text(testAudioStatus)
                    .font(.caption)
                
                Button("Play Test Audio") {
                    playTestAudio()
                }
                
                Button("Configure for Voice") {
                    Task {
                        do {
                            try await AudioSessionManager.shared.configureForVoice()
                            refreshAudioStatus()
                        } catch {
                            testAudioStatus = "Error: \(error.localizedDescription)"
                        }
                    }
                }
                
                Button("Configure for Playback") {
                    Task {
                        do {
                            try AudioSessionManager.shared.configureForPlayback()
                            refreshAudioStatus()
                        } catch {
                            testAudioStatus = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            }
            
            Section(header: Text("App Config")) {
                Text("Base URL: \(AppConfig.baseURL.absoluteString)")
                Text("Client Version: \(AppConfig.clientVersion)")
                
                Button("Test API Connection") {
                    Task {
                        testAPIConnection()
                    }
                }
            }
            
            Section(header: Text("Debug Logs")) {
                Button(showingLogs ? "Hide Logs" : "Show Logs") {
                    showingLogs.toggle()
                }
                
                if showingLogs {
                    Text(getDebugLogs())
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(nil)
                }
            }
        }
        .navigationTitle("Audio Diagnostics")
        .onAppear {
            refreshAudioStatus()
        }
    }
    
    private func refreshAudioStatus() {
        audioSessionInfo = AudioSessionManager.shared.debugStatus()
    }
    
    private func playTestAudio() {
        testAudioStatus = "Playing test audio..."
        
        Task {
            do {
                try AudioSessionManager.shared.configureForPlayback()
                
                let item = AVPlayerItem(url: testAudioUrl)
                let newPlayer = AVPlayer(playerItem: item)
                self.player = newPlayer
                
                // Add observer for playback status
                var observer: NSObjectProtocol?
                observer = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { _ in
                    testAudioStatus = "Test audio completed successfully!"
                    if let obs = observer {
                        NotificationCenter.default.removeObserver(obs)
                    }
                }
                
                newPlayer.play()
                testAudioStatus = "Test audio playing..."
            } catch {
                testAudioStatus = "Failed to play test audio: \(error.localizedDescription)"
            }
        }
    }
    
    private func testAPIConnection() {
        Task {
            do {
                testAudioStatus = "Testing API connection..."
                let url = AppConfig.baseURL.appendingPathComponent("/api/ping")
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse {
                    testAudioStatus = "API ping status: \(httpResponse.statusCode)"
                    if let string = String(data: data, encoding: .utf8) {
                        testAudioStatus += "\nResponse: \(string)"
                    }
                }
            } catch {
                testAudioStatus = "API connection failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func getDebugLogs() -> String {
        // This would ideally fetch logs from a logging system
        // For now, just return some basic info
        let session = AVAudioSession.sharedInstance()
        var logs = "--- Debug Logs ---\n"
        logs += "Audio Session Category: \(session.category.rawValue)\n"
        logs += "Audio Session Mode: \(session.mode.rawValue)\n"
        logs += "Audio Session Active: \(String(describing: session.isOtherAudioPlaying))\n"
        logs += "Base URL: \(AppConfig.baseURL.absoluteString)\n"
        return logs
    }
}
