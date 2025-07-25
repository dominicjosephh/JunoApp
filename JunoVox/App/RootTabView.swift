import SwiftUI

struct RootTabView: View {
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

                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
            }

            NowPlayingBar()
                .padding(.bottom, 60) // sits above the tab bar
        }
    }
}