import Foundation
import Combine
import UIKit

@MainActor
final class SpotifyManager: ObservableObject {
    static let shared = SpotifyManager()
    
    @Published var isConnected: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var nowPlaying: SpotifyTrack? = nil
    @Published var currentPlaybackState: PlaybackState = .stopped
    @Published var playlists: [SpotifyPlaylist] = []
    @Published var musicInsights: MusicInsights? = nil
    @Published var errorMessage: String? = nil
    
    private var accessToken: String? = nil
    private let baseURL = "http://localhost:8000" // Your backend URL
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Authentication
    
    func getAuthURL() async {
        do {
            isAuthenticating = true
            errorMessage = nil
            
            guard let url = URL(string: "\(baseURL)/api/spotify/auth") else {
                throw APIClientError.invalidURL
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let authURL = json?["auth_url"] as? String,
               let url = URL(string: authURL) {
                await UIApplication.shared.open(url)
            }
        } catch {
            errorMessage = "Failed to get auth URL: \(error.localizedDescription)"
        }
        isAuthenticating = false
    }
    
    func handleAuthCallback(code: String) async {
        do {
            isAuthenticating = true
            errorMessage = nil
            
            guard let url = URL(string: "\(baseURL)/api/spotify/token") else {
                throw APIClientError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body = ["code": code]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let token = json?["access_token"] as? String {
                accessToken = token
                isConnected = true
                await fetchCurrentPlayback()
            }
        } catch {
            errorMessage = "Authentication failed: \(error.localizedDescription)"
        }
        isAuthenticating = false
    }
    
    // MARK: - Playback Control
    
    func sendCommand(_ command: String) async {
        guard let token = accessToken else {
            errorMessage = "Not authenticated"
            return
        }
        
        do {
            guard let url = URL(string: "\(baseURL)/api/spotify/command") else {
                throw APIClientError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body = [
                "command": command,
                "spotify_token": token
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let message = json?["message"] as? String {
                print("✅ Spotify command result: \(message)")
                await fetchCurrentPlayback() // Refresh playback state
            }
        } catch {
            errorMessage = "Command failed: \(error.localizedDescription)"
        }
    }
    
    func play() async {
        await sendCommand("play")
        currentPlaybackState = .playing
    }
    
    func pause() async {
        await sendCommand("pause")
        currentPlaybackState = .paused
    }
    
    func next() async {
        await sendCommand("next")
    }
    
    func previous() async {
        await sendCommand("previous")
    }
    
    // MARK: - Data Fetching
    
    func fetchCurrentPlayback() async {
        guard let token = accessToken else { return }
        
        do {
            guard let url = URL(string: "\(baseURL)/api/spotify/playback") else {
                throw APIClientError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let item = json?["item"] as? [String: Any],
               let name = item["name"] as? String,
               let artists = item["artists"] as? [[String: Any]],
               let artistName = artists.first?["name"] as? String,
               let id = item["id"] as? String {
                
                nowPlaying = SpotifyTrack(id: id, title: name, artist: artistName)
                
                if let isPlaying = json?["is_playing"] as? Bool {
                    currentPlaybackState = isPlaying ? .playing : .paused
                }
            }
        } catch {
            print("Failed to fetch playback: \(error)")
        }
    }
    
    func createSmartPlaylist(name: String, preferences: [String: Any]) async {
        guard let token = accessToken else {
            errorMessage = "Not authenticated"
            return
        }
        
        do {
            guard let url = URL(string: "\(baseURL)/api/spotify/playlist") else {
                throw APIClientError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let body = [
                "name": name,
                "preferences": preferences
            ] as [String : Any]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let message = json?["message"] as? String {
                print("✅ Playlist created: \(message)")
            }
        } catch {
            errorMessage = "Playlist creation failed: \(error.localizedDescription)"
        }
    }
    
    func fetchMusicInsights() async {
        do {
            guard let url = URL(string: "\(baseURL)/api/spotify/insights") else {
                throw APIClientError.invalidURL
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let totalTracks = json?["total_tracks_played"] as? Int,
               let topArtists = json?["top_artists"] as? [[String: Any]] {
                
                let artists = topArtists.compactMap { dict -> TopArtist? in
                    guard let name = dict["artist"] as? String,
                          let plays = dict["plays"] as? Int else { return nil }
                    return TopArtist(name: name, playCount: plays)
                }
                
                musicInsights = MusicInsights(totalTracks: totalTracks, topArtists: artists)
            }
        } catch {
            print("Failed to fetch insights: \(error)")
        }
    }
    
    func disconnect() {
        isConnected = false
        accessToken = nil
        nowPlaying = nil
        currentPlaybackState = .stopped
        playlists = []
        musicInsights = nil
    }
}

// MARK: - Data Models

struct SpotifyTrack: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    
    var displayName: String {
        "\(title) - \(artist)"
    }
}

struct SpotifyPlaylist: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let trackCount: Int
}

struct MusicInsights: Codable {
    let totalTracks: Int
    let topArtists: [TopArtist]
}

struct TopArtist: Identifiable, Codable {
    let id = UUID()
    let name: String
    let playCount: Int
}

enum PlaybackState {
    case playing
    case paused
    case stopped
    
    var systemImageName: String {
        switch self {
        case .playing: return "pause.fill"
        case .paused, .stopped: return "play.fill"
        }
    }
}