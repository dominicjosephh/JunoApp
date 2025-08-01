import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("autoPlayVoice") private var autoPlayVoice: Bool = true
    @AppStorage("defaultPersona") private var defaultPersonaRaw: String = PersonaMode.base.rawValue

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
                            appState.selectedPersona = mode
                        }
                    }
                }
                Section(header: Text("Voice")) {
                    Toggle("Auto-play Juno’s Voice", isOn: $autoPlayVoice)
                }
                Section(header: Text("Spotify")) {
                    NavigationLink(destination: SpotifyView()) {
                        HStack {
                            Image(systemName: "music.note")
                            Text("Spotify Integration")
                            Spacer()
                            if SpotifyManager.shared.isConnected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
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
                    Text("Version: 1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
