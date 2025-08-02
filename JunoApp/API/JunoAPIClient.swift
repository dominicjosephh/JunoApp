import Foundation

// MARK: - Error type

/// Errors that can occur while making API requests.
enum APIClientError: LocalizedError {
    case invalidURL
    case noData
    case badURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .badURL:
            return "Bad URL format"
        }
    }
}

// MARK: - API client

/// A simple HTTP client for interacting with your backend. Update
/// `baseURL` with your own endpoint. Each method is async/throws
/// and returns either decoded DTOs or JSON dictionaries.
final class JunoAPIClient {
    static let shared = JunoAPIClient()
    
    private let baseURL: String
    private let session: URLSession

    /// Creates a new client.
    /// - Parameters:
    ///   - baseURL: The base URL of your API (for example, your Digital Ocean droplet).
    ///   - session: URLSession to use; defaults to `.shared`.
    init(baseURL: String = "http://127.0.0.1:8000", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Fetches the memory summary from the server and decodes it into `MemorySummaryDTO`.
    func getMemorySummary() async throws -> MemorySummaryDTO {
        guard let url = URL(string: "\(baseURL)/api/memory/summary") else {
            throw APIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        return try decoder.decode(MemorySummaryDTO.self, from: data)
    }

    /// Builds a URL for audio file paths returned by the backend. Handles absolute and relative paths.
    func buildAudioURL(from path: String) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        } else if path.hasPrefix("/") {
            return URL(string: baseURL + path)
        } else {
            return URL(string: baseURL + "/" + path)
        }
    }

    /// Sends a chat request to the server.
    /// - Parameters:
    ///   - messages: An array of message dictionaries. Each dictionary must map
    ///     keys such as "role" and "content" to strings.
    ///   - personality: The persona to use. Default is "Base".
    /// - Returns: A JSON dictionary representing the server's response.
    func chat(messages: [[String: String]], personality: String = "Base") async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw APIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["messages": messages, "personality": personality]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIClientError.noData
        }
        return json
    }

    /// Sends text to the text‑to‑speech endpoint and returns the JSON response.
    func textToSpeech(text: String, voiceMode: String = "Base") async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/api/tts") else {
            throw APIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["text": text, "voice_mode": voiceMode]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIClientError.noData
        }
        return json
    }

    /// Processes voice audio by sending it to the backend for transcription and AI response.
    /// - Parameters:
    ///   - audioData: The recorded audio data
    ///   - filename: The filename for the audio file (e.g., "voice.m4a")
    ///   - mimeType: The MIME type of the audio (e.g., "audio/m4a")
    ///   - voiceMode: The personality mode to use
    /// - Returns: A JSON dictionary with transcription, response, emotion data, etc.
    func processVoice(audioData: Data, filename: String, mimeType: String, voiceMode: String) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/api/process_audio") else {
            throw APIClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add voice_mode field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"voice_mode\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(voiceMode)\r\n".data(using: .utf8)!)
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🌐 Sending voice request to: \(url)")
        print("🌐 Content-Type: multipart/form-data; boundary=\(boundary)")
        print("🌐 Body size: \(body.count) bytes")
        print("🌐 Voice mode: \(voiceMode)")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🌐 Response status: \(httpResponse.statusCode)")
        }
        
        print("🌐 Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode response")")
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIClientError.noData
        }
        return json
    }
    
    /// Tests connection to all API endpoints
    func testConnection() async -> ConnectionTestResult {
        let startTime = Date()
        var endpointResults: [EndpointTestResult] = []
        
        // Test each endpoint
        let endpoints = [
            ("Health Check", "/api/health"),
            ("Chat", "/api/chat"),
            ("TTS", "/api/tts"),
            ("Memory Summary", "/api/memory/summary"),
            ("Performance", "/api/performance")
        ]
        
        for (name, path) in endpoints {
            let result = await testEndpoint(name: name, path: path)
            endpointResults.append(result)
        }
        
        // Determine overall status
        let successCount = endpointResults.filter { $0.status == .success }.count
        let overallStatus: ConnectionStatus
        
        if successCount == endpointResults.count {
            overallStatus = .success
        } else if successCount > 0 {
            overallStatus = .partial
        } else {
            overallStatus = .failed
        }
        
        return ConnectionTestResult(
            baseURL: baseURL,
            timestamp: startTime,
            overallStatus: overallStatus,
            endpointResults: endpointResults
        )
    }
    
    private func testEndpoint(name: String, path: String) async -> EndpointTestResult {
        let startTime = Date()
        let fullURL = "\(baseURL)\(path)"
        
        do {
            guard let url = URL(string: fullURL) else {
                return EndpointTestResult(
                    name: name,
                    url: fullURL,
                    status: .failed,
                    statusCode: nil,
                    responseTime: Date().timeIntervalSince(startTime),
                    error: "Invalid URL"
                )
            }
            
            let (_, response) = try await session.data(from: url)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            
            let status: ConnectionStatus = (200...299).contains(statusCode) ? .success : .failed
            
            return EndpointTestResult(
                name: name,
                url: fullURL,
                status: status,
                statusCode: statusCode,
                responseTime: Date().timeIntervalSince(startTime),
                error: nil
            )
            
        } catch {
            return EndpointTestResult(
                name: name,
                url: fullURL,
                status: .failed,
                statusCode: nil,
                responseTime: Date().timeIntervalSince(startTime),
                error: error.localizedDescription
            )
        }
    }
}

// MARK: - Connection Test Models

struct ConnectionTestResult {
    let baseURL: String
    let timestamp: Date
    let overallStatus: ConnectionStatus
    let endpointResults: [EndpointTestResult]
}

struct EndpointTestResult {
    let name: String
    let url: String
    let status: ConnectionStatus
    let statusCode: Int?
    let responseTime: TimeInterval
    let error: String?
}

enum ConnectionStatus {
    case success
    case partial
    case failed
}
