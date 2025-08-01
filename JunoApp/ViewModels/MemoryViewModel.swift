import Foundation
import Combine

// MARK: - View Model

@MainActor
final class MemoryViewModel: ObservableObject {
    @Published var summary: MemorySummaryDTO?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let apiClient: JunoAPIClient

    init(apiClient: JunoAPIClient = JunoAPIClient()) {
        self.apiClient = apiClient
    }

    func fetchMemorySummary() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let summary = try await apiClient.getMemorySummary()
            self.summary = summary
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            self.summary = nil
        }
    }

    func sendChat(messages: [[String: String]], personality: String = "Base") async -> [String: Any]? {
        do {
            let response = try await apiClient.chat(messages: messages, personality: personality)
            return response
        } catch {
            self.errorMessage = error.localizedDescription
            return nil
        }
    }

    func synthesizeText(_ text: String) async -> [String: Any]? {
        do {
            let result = try await apiClient.textToSpeech(text: text)
            return result
        } catch {
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
}
