import SwiftUI

@MainActor
struct SpotifyView: View {
    @StateObject private var spotifyManager = SpotifyManager.shared
    @State private var showingPlaylistCreator = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status Section
                    connectionStatusSection
                    
                    // Now Playing Section
                    if spotifyManager.isConnected {
                        nowPlayingSection
                        
                        // Playback Controls
                        playbackControlsSection
                        
                        // Smart Playlist Section
                        smartPlaylistSection
                        
                        // Music Insights Section
                        musicInsightsSection
                    }
                }
                .padding()
            }
            .navigationTitle("🎵 Spotify")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                if spotifyManager.isConnected {
                    await refreshData()
                }
            }
            .onAppear {
                Task {
                    if spotifyManager.isConnected {
                        await refreshData()
                    }
                }
            }
            .alert("Spotify", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingPlaylistCreator) {
                PlaylistCreatorSheet()
            }
        }
        .onChange(of: spotifyManager.errorMessage) { errorMessage in
            if let error = errorMessage {
                alertMessage = error
                showingAlert = true
            }
        }
    }
    
    // MARK: - Connection Status Section
    
    private var connectionStatusSection: some View {
        VStack(spacing: 16) {
            Image(systemName: spotifyManager.isConnected ? "checkmark.circle.fill" : "multiply.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(spotifyManager.isConnected ? .green : .red)
            
            Text(spotifyManager.isConnected ? "Connected to Spotify" : "Not Connected")
                .font(.headline)
                .foregroundColor(spotifyManager.isConnected ? .green : .primary)
            
            if !spotifyManager.isConnected {
                Button("Connect to Spotify") {
                    Task {
                        await spotifyManager.getAuthURL()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(spotifyManager.isAuthenticating)
                .overlay {
                    if spotifyManager.isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
            } else {
                Button("Disconnect") {
                    spotifyManager.disconnect()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Now Playing Section
    
    private var nowPlayingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.green)
                Text("Now Playing")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    Task {
                        await spotifyManager.fetchCurrentPlayback()
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            if let track = spotifyManager.nowPlaying {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: spotifyManager.currentPlaybackState.systemImageName)
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                Text("No track currently playing")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Playback Controls Section
    
    private var playbackControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.tap")
                    .foregroundColor(.blue)
                Text("Playback Controls")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    Task { await spotifyManager.previous() }
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    Task {
                        switch spotifyManager.currentPlaybackState {
                        case .playing:
                            await spotifyManager.pause()
                        case .paused, .stopped:
                            await spotifyManager.play()
                        }
                    }
                }) {
                    Image(systemName: spotifyManager.currentPlaybackState.systemImageName)
                        .font(.title)
                        .frame(width: 60, height: 60)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    Task { await spotifyManager.next() }
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Smart Playlist Section
    
    private var smartPlaylistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundColor(.purple)
                Text("Smart Playlists")
                    .font(.headline)
                Spacer()
            }
            
            Button("Create Smart Playlist") {
                showingPlaylistCreator = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Music Insights Section
    
    private var musicInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.orange)
                Text("Music Insights")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    Task {
                        await spotifyManager.fetchMusicInsights()
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            if let insights = spotifyManager.musicInsights {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "music.note")
                        Text("Total Tracks: \(insights.totalTracks)")
                            .font(.subheadline)
                    }
                    
                    if !insights.topArtists.isEmpty {
                        Text("Top Artists:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.top, 4)
                        
                        ForEach(insights.topArtists.prefix(5)) { artist in
                            HStack {
                                Text("•")
                                Text(artist.name)
                                Spacer()
                                Text("\(artist.playCount) plays")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                Text("No insights available yet")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func refreshData() async {
        async let playback: Void = spotifyManager.fetchCurrentPlayback()
        async let insights: Void = spotifyManager.fetchMusicInsights()
        
        _ = await (playback, insights)
    }
}

// MARK: - Playlist Creator Sheet

struct PlaylistCreatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var spotifyManager = SpotifyManager.shared
    @State private var playlistName = ""
    @State private var selectedMood = "Happy"
    @State private var selectedGenre = "Pop"
    @State private var isCreating = false
    
    let moods = ["Happy", "Sad", "Energetic", "Chill", "Romantic", "Party"]
    let genres = ["Pop", "Rock", "Hip-Hop", "Electronic", "Jazz", "Classical"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Playlist Details") {
                    TextField("Playlist Name", text: $playlistName)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Preferences") {
                    Picker("Mood", selection: $selectedMood) {
                        ForEach(moods, id: \.self) { mood in
                            Text(mood).tag(mood)
                        }
                    }
                    
                    Picker("Genre", selection: $selectedGenre) {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre).tag(genre)
                        }
                    }
                }
                
                Section {
                    Button("Create Playlist") {
                        Task {
                            await createPlaylist()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(playlistName.isEmpty || isCreating)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                    }
                }
            }
            .navigationTitle("Create Smart Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
    
    private func createPlaylist() async {
        isCreating = true
        
        let preferences = [
            "mood": selectedMood,
            "genre": selectedGenre
        ]
        
        await spotifyManager.createSmartPlaylist(name: playlistName, preferences: preferences)
        
        isCreating = false
        dismiss()
    }
}

// MARK: - Preview

struct SpotifyView_Previews: PreviewProvider {
    static var previews: some View {
        SpotifyView()
    }
}