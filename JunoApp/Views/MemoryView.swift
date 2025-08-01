import SwiftUI

// MARK: - Using DTOs from Models/MemorySummaryDTO.swift instead of local definitions

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

