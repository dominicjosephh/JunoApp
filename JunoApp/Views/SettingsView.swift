import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("autoPlayVoice") private var autoPlayVoice: Bool = true
    @AppStorage("defaultPersona") private var defaultPersonaRaw: String = PersonaMode.Base.rawValue

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personality")) {
                    Picker("Default Persona", selection: $defaultPersonaRaw) {
                        ForEach(PersonaMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode.rawValue)
                        }
                    }
                    .onChange(of: defaultPersonaRaw) { newValue in
                        if let mode = PersonaMode(rawValue: newValue) {
                            appState.persona = mode
                        }
                    }
                }
                Section(header: Text("Voice")) {
                    Toggle("Auto-play Juno’s Voice", isOn: $autoPlayVoice)
                }
                Section(header: Text("Spotify")) {
                    Button(action: connectSpotify) {
                        HStack {
                            Image(systemName: "music.note")
                            Text("Connect Spotify")
                        }
                    }
                }
                Section(header: Text("Diagnostics")) {
                    NavigationLink(destination: ConnectionTestView()) {
                        HStack {
                            Image(systemName: "network")
                            Text("Connection Test")
                        }
                    }
                }
                Section(header: Text("App Info")) {
                    Text("Version: \(AppConfig.clientVersion)")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func connectSpotify() {
        SpotifyManager.shared.connect()
    }
}
