import Foundation
import AVFoundation

public enum AppConfig {
    public static var baseURL: URL = URL(string: "https://djpresence.com")!
    public static let clientVersion: String = "ios@1.0.0"
}

// MARK: - Persona
public enum PersonaMode: String, Codable {
    case Base
    case Empathy
    case Hype
    case Sassy
}

// MARK: - Errors
public enum APIClientError: Error, LocalizedError {
    case badURL
    case invalidHTTPStatus(Int, String?)
    case decodingFailed(Error)
    case encodingFailed(Error)
    case transport(Error)
    case server(String)
    case noData
    case fileNotFound
    case unknown

    public var errorDescription: String? {
        switch self {
        case .badURL: return "Bad URL"
        case .invalidHTTPStatus(let code, let body):
            return "HTTP \(code). Body: \(body ?? "<none>")"
        case .decodingFailed(let err): return "Decoding failed: \(err.localizedDescription)"
        case .encodingFailed(let err): return "Encoding failed: \(err.localizedDescription)"
        case .transport(let err): return "Network error: \(err.localizedDescription)"
        case .server(let msg): return "Server error: \(msg)"
        case .noData: return "No data returned"
        case .fileNotFound: return "File not found"
        case .unknown: return "Unknown error"
        }
    }
}

// MARK: - DTOs
public struct ChatMessageDTO: Codable {
    public let role: String
    public let content: String
}

public struct ChatRequestDTO: Codable {
    public let messages: [ChatMessageDTO]
    public let personality: String
}

public struct ChatResponseDTO: Codable {
    public let reply: String?
    public let error: String?
}

public struct TTSRequestDTO: Codable {
    public let text: String
}

public struct TTSResponseDTO: Codable {
    public let audio_url: String?
    public let error: String?
}

public struct VoiceEmotionDTO: Codable {
    public let emotion: String?
    public let confidence: Double?
}

public struct VoiceResponseDTO: Codable {
    public let reply: String?
    public let error: String?
    public let voice_mode: String?
    public let adapted_voice_mode: String?
    public let emotion_data: VoiceEmotionDTO?
}

public struct MemorySummaryDTO: Codable {
    public struct ConversationStats: Codable {
        public let total_conversations: Int
        public let avg_importance: Double
        public let positive_count: Int
        public let negative_count: Int
    }
    public struct PersonalFact: Codable, Identifiable {
        public let id: Int
        public let category: String
        public let key: String
        public let value: String
        public let confidence: Double
    }
    public struct Topic: Codable, Identifiable {
        public let id: Int
        public let topic: String
        public let mentions: Int
        public let associated_emotion: String?
        public let importance_score: Double
    }
    public struct Relationship: Codable, Identifiable {
        public let id: Int
        public let name: String
        public let relationship_type: String
        public let last_mentioned: String?
    }
    public let personal_facts: [PersonalFact]
    public let favorite_topics: [Topic]
    public let relationships: [Relationship]
    public let conversation_stats: ConversationStats
}

// MARK: - Client
public final class JunoAPIClient {
    public static let shared = JunoAPIClient()
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    public func chat(messages: [ChatMessageDTO], personality: PersonaMode = .Base) async throws -> ChatResponseDTO {
        let url = AppConfig.baseURL.appendingPathComponent("/api/chat")
        let req = ChatRequestDTO(messages: messages, personality: personality.rawValue)
        return try await postJSON(url, req, ChatResponseDTO.self)
    }

    public func tts(text: String) async throws -> TTSResponseDTO {
        let url = AppConfig.baseURL.appendingPathComponent("/api/tts")
        let req = TTSRequestDTO(text: text)
        return try await postJSON(url, req, TTSResponseDTO.self)
    }

    public func processVoice(audioData: Data, filename: String = "voice.m4a",
                             mimeType: String = "audio/m4a",
                             voiceMode: PersonaMode = .Base) async throws -> VoiceResponseDTO {
        let url = AppConfig.baseURL.appendingPathComponent("/api/voice")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(&request)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let body = buildMultipart(boundary: boundary,
                                  fields: [("voice_mode", voiceMode.rawValue)],
                                  fileField: ("audio_file", filename, mimeType, audioData))
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)
        return try decoder.decode(VoiceResponseDTO.self, from: data)
    }

    public func getMemorySummary() async throws -> MemorySummaryDTO {
        let url = AppConfig.baseURL.appendingPathComponent("/api/memory/summary")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(&request)
        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)
        return try decoder.decode(MemorySummaryDTO.self, from: data)
    }

    // MARK: - Helpers
    private func postJSON<T: Codable, R: Codable>(_ url: URL, _ body: T, _ type: R.Type) async throws -> R {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)
        return try decoder.decode(R.self, from: data)
    }

    private func addHeaders(_ request: inout URLRequest) {
        request.setValue(AppConfig.clientVersion, forHTTPHeaderField: "X-Juno-Client")
    }

    private func validate(_ response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw APIClientError.invalidHTTPStatus(http.statusCode, String(data: data ?? Data(), encoding: .utf8))
        }
    }

    private func buildMultipart(boundary: String,
                                fields: [(name: String, value: String)],
                                fileField: (name: String, filename: String, mimeType: String, data: Data)) -> Data {
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"
        for field in fields {
            body.appendString(boundaryPrefix)
            body.appendString("Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n")
            body.appendString("\(field.value)\r\n")
        }
        body.appendString(boundaryPrefix)
        body.appendString("Content-Disposition: form-data; name=\"\(fileField.name)\"; filename=\"\(fileField.filename)\"\r\n")
        body.appendString("Content-Type: \(fileField.mimeType)\r\n\r\n")
        body.append(fileField.data)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
