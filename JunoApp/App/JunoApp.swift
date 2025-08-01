import SwiftUI

@main
struct JunoApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        // Handle Spotify authentication callback
        if url.scheme == "junovox" && url.host == "callback" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let code = queryItems.first(where: { $0.name == "code" })?.value {
                Task {
                    await SpotifyManager.shared.handleAuthCallback(code: code)
                }
            }
        }
    }
}
