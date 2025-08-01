import Foundation

// MARK: - DTOs for Memory Summary

struct MemorySummaryDTO: Codable {
    let conversationStats: ConversationStatsDTO
    let personalFacts: [PersonalFactDTO]
    let favoriteTopics: [FavoriteTopicDTO]
    let relationships: [RelationshipDTO]
}

// Customize the below DTOs to fit your backend response structure!

struct ConversationStatsDTO: Codable {
    let totalConversations: Int
    let positiveCount: Int
    let negativeCount: Int
    let avgImportance: Double
}

struct PersonalFactDTO: Codable, Identifiable {
    var id = UUID()
    let key: String
    let value: String
    let confidence: Double
}

struct FavoriteTopicDTO: Codable, Identifiable {
    var id = UUID()
    let topic: String
    let mentions: Int
}

struct RelationshipDTO: Codable, Identifiable {
    var id = UUID()
    let name: String
    let relationshipType: String
    let lastMentioned: Date?
}
