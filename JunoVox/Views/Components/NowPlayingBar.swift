import SwiftUI

struct NowPlayingBar: View {
    @ObservedObject var spotify = SpotifyManager.shared

    var body: some View {
        if spotify.isConnected, let track = spotify.nowPlaying {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).bold().lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: spotify.pause) {
                    Image(systemName: "pause.fill")
                }
                Button(action: spotify.next) {
                    Image(systemName: "forward.fill")
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding([.horizontal, .bottom])
        }
    }
}