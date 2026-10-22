import SwiftUI
import AppKit

struct TrackListView: View {
    let tracks: [Track]
    let source: TrackSource
    @Binding var selection: Set<UUID>
    @Binding var sortOrder: [KeyPathComparator<Track>]

    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var player: PlayerEngine

    var body: some View {
        Table(tracks, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Title", value: \.title) { track in
                titleCell(track)
            }
            .width(min: 220, ideal: 340)

            TableColumn("Artist", value: \.artist) { track in
                Text(track.artist)
                    .foregroundStyle(isCurrent(track) ? .primary : .secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .width(min: 120, ideal: 180)

            TableColumn("Album", value: \.album) { track in
                Text(track.album)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .width(min: 120, ideal: 180)

            TableColumn("Time", value: \.duration) { track in
                Text(formattedTime(track.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 70)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: UUID.self) { ids in
            menuItems(for: ids)
        } primaryAction: { ids in
            if let id = ids.first, let track = tracks.first(where: { $0.id == id }) {
                player.play(track, in: tracks)
            }
        }
    }

    private func titleCell(_ track: Track) -> some View {
        HStack(spacing: 10) {
            ArtworkView(track: track, size: 32, cornerRadius: 6)
            Text(track.title)
                .fontWeight(isCurrent(track) ? .semibold : .regular)
                .foregroundStyle(isCurrent(track) ? Color.accentColor : .primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if isCurrent(track), player.isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
            if library.isFavorite(track) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func menuItems(for ids: Set<UUID>) -> some View {
        let selected = tracks.filter { ids.contains($0.id) }
        if !selected.isEmpty {
            Button("Play") {
                if let first = selected.first {
                    player.play(first, in: tracks)
                }
            }
            Button("Play Next") {
                for track in selected.reversed() {
                    player.playNext(track)
                }
            }
            Divider()
            Menu("Add to Playlist") {
                if library.playlists.isEmpty {
                    Text("No Playlists")
                } else {
                    ForEach(library.playlists) { playlist in
                        Button(playlist.name) {
                            for track in selected {
                                library.add(track, toPlaylist: playlist.id)
                            }
                        }
                    }
                }
            }
            Button(favoriteLabel(for: selected)) {
                let allFavorite = selected.allSatisfy { library.isFavorite($0) }
                for track in selected {
                    library.setFavorite(track, !allFavorite)
                }
            }
            Divider()
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting(selected.map(\.url))
            }
            switch source {
            case .library:
                Button("Remove from Library", role: .destructive) {
                    for track in selected {
                        library.remove(track)
                    }
                }
            case .favorites:
                Button("Remove from Favorites", role: .destructive) {
                    for track in selected {
                        library.setFavorite(track, false)
                    }
                }
            case .playlist(let playlistID):
                Button("Remove from Playlist", role: .destructive) {
                    for track in selected {
                        library.remove(track, fromPlaylist: playlistID)
                    }
                }
            }
        }
    }

    private func favoriteLabel(for tracks: [Track]) -> String {
        let allFavorite = tracks.allSatisfy { library.isFavorite($0) }
        if allFavorite {
            return tracks.count == 1 ? "Remove from Favorites" : "Remove from Favorites"
        }
        return "Add to Favorites"
    }

    private func isCurrent(_ track: Track) -> Bool {
        player.currentTrack?.id == track.id
    }
}
