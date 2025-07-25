import Foundation
import Combine

final class SpotifyManager: ObservableObject {
    static let shared = SpotifyManager()
    
    @Published var isConnected: Bool = false
    @Published var nowPlaying: SpotifyTrack? = nil
    
    private init() {}

    func connect() {
        // Simulate connection for now
        isConnected = true
        nowPlaying = SpotifyTrack(id: "1", title: "Welcome Track", artist: "Juno")
    }

    func disconnect() {
        isConnected = false
        nowPlaying = nil
    }

    func play(track uri: String) {
        print("Stub play track: \(uri)")
        nowPlaying = SpotifyTrack(id: uri, title: "Stub Track", artist: "Artist")
    }

    func pause() {
        print("Stub pause")
    }

    func next() {
        Log.d("Stub next track")
    }
}

struct SpotifyTrack: Identifiable {
    let id: String
    let title: String
    let artist: String
}