import Foundation

enum PersonaMode: String, CaseIterable {
    case base = "Base"
    case sassy = "Sassy"
    case empathy = "Empathy"
    case hype = "Hype"
    
    var displayName: String {
        return self.rawValue
    }
}
