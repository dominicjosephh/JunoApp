import SwiftUI

// MARK: - Data models

/// Represents high‑level conversation statistics.
struct ConversationStats {
    let totalConversations: Int
    let positiveCount: Int
    let negativeCount: Int
    let avgImportance: Double
}

/// Represents a single personal fact learned by Juno.
struct PersonalFact: Identifiable {
    let id = UUID()
    let key: String
    let value: String
    let confidence: Double
}

/// Represents one of the user's favourite topics.
struct FavoriteTopic: Identifiable {
    let id = UUID()
    let topic: String
    let mentions: Int
}

/// Represents an important relationship in the user's life.
struct Relationship: Identifiable {
    let id = UUID()
    let name: String
    let relationshipType: String
    let lastMentioned: Date?
}

/// Aggregates all of the above pieces of information into a single
/// summary object. If you already have a model for this coming
/// from your API, you can delete this and use your own type.
struct MemorySummary {
    let conversationStats: ConversationStats
    let personalFacts: [PersonalFact]
    let favoriteTopics: [FavoriteTopic]
    let relationships: [Relationship]
}

// MARK: - View model removed (using ViewModels/MemoryViewModel.swift instead)

// MARK: - View

/// Displays a summary of Juno's memory, including conversation statistics,
/// personal facts, favourite topics and relationships. Tapping the refresh
/// button will reload the summary.
struct MemoryView: View {
    @StateObject private var viewModel = MemoryViewModel()

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading Juno’s Memory…")
                } else if let summary = viewModel.summary {
                    List {
                        // Conversation statistics section
                        Section(header: Text("Conversation Stats")) {
                            Text("Total: \(summary.conversationStats.totalConversations)")
                            Text("Positive: \(summary.conversationStats.positiveCount)")
                            Text("Negative: \(summary.conversationStats.negativeCount)")
                            Text(String(format: "Avg Importance: %.2f", summary.conversationStats.avgImportance))
                        }
                        // Personal facts section
                        if !summary.personalFacts.isEmpty {
                            Section(header: Text("Personal Facts")) {
                                ForEach(summary.personalFacts) { fact in
                                    VStack(alignment: .leading) {
                                        Text("\(fact.key): \(fact.value)")
                                        Text("Confidence: \(String(format: "%.2f", fact.confidence))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        // Favourite topics section
                        if !summary.favoriteTopics.isEmpty {
                            Section(header: Text("Favorite Topics")) {
                                ForEach(summary.favoriteTopics) { topic in
                                    VStack(alignment: .leading) {
                                        Text(topic.topic)
                                        Text("Mentions: \(topic.mentions)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        // Relationships section
                        if !summary.relationships.isEmpty {
                            Section(header: Text("Relationships")) {
                                ForEach(summary.relationships) { rel in
                                    VStack(alignment: .leading) {
                                        Text("\(rel.name) – \(rel.relationshipType)")
                                        if let last = rel.lastMentioned {
                                            Text("Last mentioned: \(last.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("No memory data available.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Juno’s Memory")
            .toolbar {
                Button(action: { Task { await viewModel.fetchMemorySummary() } }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .onAppear {
                if viewModel.summary == nil {
                    Task { await viewModel.fetchMemorySummary() }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MemoryView_Previews: PreviewProvider {
    static var previews: some View {
        MemoryView()
    }
}
#endif

