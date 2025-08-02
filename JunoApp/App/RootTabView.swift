import SwiftUI

struct RootTabView: View {
    @State private var showDebugView = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                ChatView()
                    .tabItem {
                        Image(systemName: "message.fill")
                        Text("Chat")
                    }

                ConversationView()
                    .tabItem {
                        Image(systemName: "mic.fill")
                        Text("Conversation")
                    }

                MemoryView()
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text("Memory")
                    }
                
                StarvationGameView()
                    .tabItem {
                        Image(systemName: "gamecontroller.fill")
                        Text("Game")
                    }
                
                SpotifyView()
                    .tabItem {
                        Image(systemName: "music.note")
                        Text("Spotify")
                    }

                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
                
                #if DEBUG
                NavigationView {
                    AudioDebugView()
                }
                .tabItem {
                    Image(systemName: "waveform")
                    Text("Debug")
                }
                #endif
            }

            NowPlayingBar()
                .padding(.bottom, 60) // sits above the tab bar
        }
        .onShake {
            // Triple tap anywhere to show debug view in release builds
            showDebugView.toggle()
        }
        .sheet(isPresented: $showDebugView) {
            NavigationView {
                AudioDebugView()
                    .navigationBarItems(trailing: Button("Close") {
                        showDebugView = false
                    })
            }
        }
    }
}

// Shake gesture detection
extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}

struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}
