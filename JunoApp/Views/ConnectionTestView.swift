import SwiftUI

struct ConnectionTestView: View {
    @StateObject private var viewModel = ConnectionTestViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: connectionStatusIcon)
                            .font(.system(size: 40))
                            .foregroundColor(connectionStatusColor)
                        
                        Text("API Connection Status")
                            .font(.title2)
                            .bold()
                        
                        if let result = viewModel.testResult {
                            Text("Last tested: \(formatDate(result.timestamp))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Overall status
                    if let result = viewModel.testResult {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Overall Status:")
                                    .font(.headline)
                                Spacer()
                                Text(result.overallStatus.displayName)
                                    .font(.headline)
                                    .foregroundColor(result.overallStatus.color)
                            }
                            
                            HStack {
                                Text("Base URL:")
                                    .font(.subheadline)
                                Spacer()
                                Text(result.baseURL)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Endpoint results
                    if let result = viewModel.testResult {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Endpoint Tests")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(result.endpointResults, id: \.name) { endpoint in
                                EndpointResultRow(endpoint: endpoint)
                            }
                        }
                    }
                    
                    // Test button
                    Button {
                        viewModel.runConnectionTest()
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(viewModel.isLoading ? "Testing..." : "Run Connection Test")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal)
                    
                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("Connection Test")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.runConnectionTest()
            }
        }
    }
    
    private var connectionStatusIcon: String {
        guard let result = viewModel.testResult else { return "network" }
        switch result.overallStatus {
        case .success:
            return "checkmark.circle.fill"
        case .partial:
            return "exclamationmark.triangle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private var connectionStatusColor: Color {
        guard let result = viewModel.testResult else { return .gray }
        switch result.overallStatus {
        case .success:
            return .green
        case .partial:
            return .orange
        case .failed:
            return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct EndpointResultRow: View {
    let endpoint: EndpointTestResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(endpoint.name)
                    .font(.subheadline)
                    .bold()
                
                Text(endpoint.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 12) {
                    if let statusCode = endpoint.statusCode {
                        Text("HTTP \(statusCode)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusCodeColor(statusCode).opacity(0.2))
                            .foregroundColor(statusCodeColor(statusCode))
                            .cornerRadius(4)
                    }
                    
                    Text("\(Int(endpoint.responseTime * 1000))ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let error = endpoint.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Image(systemName: endpoint.status.icon)
                .font(.system(size: 20))
                .foregroundColor(endpoint.status.color)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private func statusCodeColor(_ code: Int) -> Color {
        switch code {
        case 200...299:
            return .green
        case 400...499:
            return .orange
        case 500...599:
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - ViewModel

@MainActor
class ConnectionTestViewModel: ObservableObject {
    @Published var testResult: ConnectionTestResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func runConnectionTest() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = await JunoAPIClient.shared.testConnection()
                self.testResult = result
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Extensions

extension ConnectionStatus {
    var displayName: String {
        switch self {
        case .success:
            return "Connected"
        case .partial:
            return "Partial"
        case .failed:
            return "Failed"
        }
    }
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .partial:
            return .orange
        case .failed:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .partial:
            return "exclamationmark.triangle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
}

#Preview {
    ConnectionTestView()
}