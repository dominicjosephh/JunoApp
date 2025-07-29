import Foundation

@MainActor
final class MemoryViewModel: ObservableObject {
    @Published var summary: MemorySummaryDTO?
    @Published var isLoading = false

    func fetchSummary() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await JunoAPIClient.shared.getMemorySummary()
            summary = data
        } catch {
            Log.e("Error fetching memory: \(error.localizedDescription)")
            summary = nil
        }
    }
}
