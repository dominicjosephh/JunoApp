import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var selectedPersona: PersonaMode = .base
    @Published var isPlaying: Bool = false
    @Published var currentlyPlayingId: UUID?
}
