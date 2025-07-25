import Foundation

final class AppState: ObservableObject {
    @Published var persona: PersonaMode = .Base
}