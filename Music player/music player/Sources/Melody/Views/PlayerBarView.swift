import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var player: PlayerEngine

    @State private var isSeeking = false
    @State private var seekValue: Double = 0

    var body: some View {
        HStack(spacing: 16) {
            nowPlayingInfo
                .frame(maxWidth: .infinity, alignment: .leading)
            transportControls
            volumeControls
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Sections

    private var nowPlayingInfo: some View {
        HStack(spacing: 12) {
            ArtworkView(track: player.currentTrack, size: 54, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(player.currentTrack?.title ?? "Not Playing")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(player.currentTrack?.artist ?? " ")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 170, alignment: .leading)

            if let track = player.currentTrack {
                Button {
                    library.setFavorite(track, !library.isFavorite(track))
                } label: {
                    Image(systemName: library.isFavorite(track) ? "heart.fill" : "heart")
                        .foregroundStyle(library.isFavorite(track) ? Color.red : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle favorite")
            }
        }
    }

    private var transportControls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 22) {
                Button {
                    player.isShuffled.toggle()
                } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(player.isShuffled ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Shuffle")

                Button {
                    player.previous()
                } label: {
                    Image(systemName: "backward.fill")
                }
                .buttonStyle(.plain)
                .disabled(player.currentTrack == nil)
                .help("Previous (⌘←)")

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34))
                }
                .buttonStyle(.plain)
                .disabled(player.currentTrack == nil && player.isQueueEmpty)
                .help("Play/Pause (Space)")

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.plain)
                .disabled(player.currentTrack == nil)
                .help("Next (⌘→)")

                Button {
                    player.repeatMode = player.repeatMode.next
                } label: {
                    Image(systemName: player.repeatMode.symbolName)
                        .foregroundStyle(player.repeatMode == .off ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
                .help(player.repeatMode.label)
            }

            HStack(spacing: 8) {
                Text(formattedTime(displayTime))
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)

                seekSlider

                Text(formattedTime(player.duration))
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)
            }
        }
        .frame(width: 430)
    }

    private var seekSlider: some View {
        Slider(
            value: Binding(
                get: { isSeeking ? seekValue : min(player.currentTime, max(player.duration, 0)) },
                set: { seekValue = $0 }
            ),
            in: 0...max(player.duration, 0.01),
            onEditingChanged: { editing in
                if editing {
                    seekValue = min(player.currentTime, max(player.duration, 0))
                    isSeeking = true
                } else {
                    player.seek(to: seekValue)
                    isSeeking = false
                }
            }
        )
        .controlSize(.small)
        .disabled(player.duration <= 0)
    }

    private var volumeControls: some View {
        HStack(spacing: 8) {
            Button {
                player.volume = player.volume > 0 ? 0 : 0.8
            } label: {
                Image(systemName: volumeSymbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .help("Mute")

            Slider(value: $player.volume, in: 0...1)
                .controlSize(.small)
                .frame(width: 90)
        }
    }

    private var displayTime: Double {
        isSeeking ? seekValue : player.currentTime
    }

    private var volumeSymbol: String {
        if player.volume <= 0.001 { return "speaker.slash.fill" }
        if player.volume < 0.34 { return "speaker.fill" }
        if player.volume < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
