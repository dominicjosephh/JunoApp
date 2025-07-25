import SwiftUI

struct MemoryView: View {
    @StateObject private var viewModel = MemoryViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading Juno’s Memory…")
                } else if let summary = viewModel.summary {
                    List {
                        Section(header: Text("Conversation Stats")) {
                            Text("Total: \(summary.conversation_stats.total_conversations)")
                            Text("Positive: \(summary.conversation_stats.positive_count)")
                            Text("Negative: \(summary.conversation_stats.negative_count)")
                            Text(String(format: "Avg Importance: %.2f",
                                        summary.conversation_stats.avg_importance))
                        }
                        if !summary.personal_facts.isEmpty {
                            Section(header: Text("Personal Facts")) {
                                ForEach(summary.personal_facts) { fact in
                                    VStack(alignment: .leading) {
                                        Text("\(fact.key): \(fact.value)")
                                        Text("Confidence: \(String(format: "%.2f", fact.confidence))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        if !summary.favorite_topics.isEmpty {
                            Section(header: Text("Favorite Topics")) {
                                ForEach(summary.favorite_topics) { topic in
                                    VStack(alignment: .leading) {
                                        Text(topic.topic)
                                        Text("Mentions: \(topic.mentions)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        if !summary.relationships.isEmpty {
                            Section(header: Text("Relationships")) {
                                ForEach(summary.relationships) { rel in
                                    VStack(alignment: .leading) {
                                        Text("\(rel.name) – \(rel.relationship_type)")
                                        if let last = rel.last_mentioned {
                                            Text("Last mentioned: \(last)")
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
                Button(action: { Task { await viewModel.fetchSummary() } }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .onAppear {
                if viewModel.summary == nil {
                    Task { await viewModel.fetchSummary() }
                }
            }
        }
    }
}