import Foundation

extension PersonaMode: CaseIterable {
    public static var allCases: [PersonaMode] {
        [.Base, .Empathy, .Hype, .Sassy]
    }
}