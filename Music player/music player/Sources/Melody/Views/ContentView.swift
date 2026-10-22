import SwiftUI
import AppKit

enum SidebarItem: Hashable {
    case allSongs
    case favorites
    case playlist(UUID)
}

enum TrackSource: Equatable {
    case library
    case favorites
    case playlist(UUID)
}

struct ContentView: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var player: PlayerEngine

    @State private var sidebarSelection: SidebarItem? = .allSongs
    @State private var searchText = ""
    @State private var sortOrder: [KeyPathComparator<Track>] = [KeyPathComparator(\Track.title, order: .forward)]
    @State private var tableSelection = Set<UUID>()
    @State private var isDropTargeted = false

    @State private var showingNewPlaylist = false
    @State private var newPlaylistName = ""
    @State private var playlistToRename: Playlist?
    @State private var renameText = ""
    @State private var playlistToDelete: Playlist?
    @State private var showingPlaybackError = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search your music")
        .frame(minWidth: 960, minHeight: 600)
        .dropDestination(for: URL.self) { urls, _ in
            library.importURLs(urls)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                dropOverlay
            }
        }
        .alert("Playback Error", isPresented: $showingPlaybackError) {
            Button("OK") { player.errorMessage = nil }
        } message: {
            Text(player.errorMessage ?? "")
        }
        .onChange(of: player.errorMessage) { _, newValue in
            showingPlaybackError = newValue != nil
        }
        .alert("New Playlist", isPresented: $showingNewPlaylist) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Create") {
                let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let playlist = library.createPlaylist(named: name)
                sidebarSelection = .playlist(playlist.id)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Playlist", isPresented: showingRenameAlert) {
            TextField("Playlist name", text: $renameText)
            Button("Rename") {
                if let playlist = playlistToRename {
                    library.renamePlaylist(playlist.id, to: renameText)
                }
                playlistToRename = nil
            }
            Button("Cancel", role: .cancel) { playlistToRename = nil }
        }
        .alert("Delete Playlist?", isPresented: showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let playlist = playlistToDelete {
                    library.deletePlaylist(playlist.id)
                    if sidebarSelection == .playlist(playlist.id) {
                        sidebarSelection = .allSongs
                    }
                }
                playlistToDelete = nil
            }
            Button("Cancel", role: .cancel) { playlistToDelete = nil }
        } message: {
            Text("“\(playlistToDelete?.name ?? "")” will be removed. Your songs stay in the library.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            Section("Library") {
                Label("All Songs", systemImage: "music.note.list")
                    .tag(SidebarItem.allSongs)
                Label("Favorites", systemImage: "heart")
                    .tag(SidebarItem.favorites)
            }
            Section("Playlists") {
                ForEach(library.playlists) { playlist in
                    Label(playlist.name, systemImage: "music.note.list")
                        .tag(SidebarItem.playlist(playlist.id))
                        .contextMenu {
                            Button("Rename…") {
                                renameText = playlist.name
                                playlistToRename = playlist
                            }
                            Button("Delete", role: .destructive) {
                                playlistToDelete = playlist
                            }
                        }
                }
                Button {
                    newPlaylistName = ""
                    showingNewPlaylist = true
                } label: {
                    Label("New Playlist", systemImage: "plus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            importStatus
        }
        .onChange(of: sidebarSelection) { _, _ in
            tableSelection.removeAll()
        }
    }

    @ViewBuilder
    private var importStatus: some View {
        if library.isImporting {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(library.importStatusText ?? "Importing…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
        } else if let status = library.importStatusText {
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Detail

    private var detail: some View {
        VStack(spacing: 0) {
            if displayedTracks.isEmpty {
                emptyState
            } else {
                libraryHeader
                TrackListView(
                    tracks: displayedTracks,
                    source: currentSource,
                    selection: $tableSelection,
                    sortOrder: $sortOrder
                )
            }
            Divider()
            PlayerBarView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    library.importURLs(ImportPanel.chooseFiles())
                } label: {
                    Label("Import Files", systemImage: "plus")
                }
                .help("Import audio files (⌘O)")

                Button {
                    library.importURLs(ImportPanel.chooseFolder())
                } label: {
                    Label("Import Folder", systemImage: "folder.badge.plus")
                }
                .help("Import a folder (⇧⌘O)")
            }
        }
    }

    private var libraryHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentTitle)
                    .font(.system(size: 20, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                playAll(shuffled: false)
            } label: {
                Label("Play All", systemImage: "play.fill")
            }
            Button {
                playAll(shuffled: true)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var emptyState: some View {
        if library.tracks.isEmpty {
            ContentUnavailableView {
                Label("Your Library Is Empty", systemImage: "music.note.list")
            } description: {
                Text("Drag and drop audio files here, or import from your Mac.")
            } actions: {
                Button("Import Files…") {
                    library.importURLs(ImportPanel.chooseFiles())
                }
                Button("Import Folder…") {
                    library.importURLs(ImportPanel.chooseFolder())
                }
            }
        } else if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView(
                "No Songs",
                systemImage: "music.note.list",
                description: Text("Nothing here yet.")
            )
        }
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
            .background(Color.accentColor.opacity(0.08))
            .overlay {
                Label("Drop music to add", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(10)
            .allowsHitTesting(false)
    }

    // MARK: - Derived state

    private var currentSource: TrackSource {
        switch sidebarSelection {
        case .favorites: return .favorites
        case .playlist(let id): return .playlist(id)
        case .allSongs, .none: return .library
        }
    }

    private var currentTitle: String {
        switch sidebarSelection {
        case .allSongs, .none: return "All Songs"
        case .favorites: return "Favorites"
        case .playlist(let id):
            return library.playlists.first(where: { $0.id == id })?.name ?? "Playlist"
        }
    }

    private var baseTracks: [Track] {
        switch sidebarSelection {
        case .allSongs, .none:
            return library.tracks
        case .favorites:
            return library.tracks.filter { library.favoriteIDs.contains($0.id) }
        case .playlist(let id):
            guard let playlist = library.playlists.first(where: { $0.id == id }) else { return [] }
            return playlist.trackIDs.compactMap { trackID in
                library.tracks.first { $0.id == trackID }
            }
        }
    }

    private var displayedTracks: [Track] {
        var list = baseTracks
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            list = list.filter { track in
                track.title.localizedCaseInsensitiveContains(query)
                    || track.artist.localizedCaseInsensitiveContains(query)
                    || track.album.localizedCaseInsensitiveContains(query)
            }
        }
        return list.sorted(using: sortOrder)
    }

    private var subtitle: String {
        let count = displayedTracks.count
        let total = displayedTracks.reduce(0) { $0 + $1.duration }
        let songLabel = count == 1 ? "song" : "songs"
        if total > 0 {
            return "\(count) \(songLabel) · \(formattedTime(total))"
        }
        return "\(count) \(songLabel)"
    }

    private var showingRenameAlert: Binding<Bool> {
        Binding(
            get: { playlistToRename != nil },
            set: { if !$0 { playlistToRename = nil } }
        )
    }

    private var showingDeleteAlert: Binding<Bool> {
        Binding(
            get: { playlistToDelete != nil },
            set: { if !$0 { playlistToDelete = nil } }
        )
    }

    private func playAll(shuffled: Bool) {
        guard let first = displayedTracks.first else { return }
        if shuffled {
            player.isShuffled = true
        }
        player.play(first, in: displayedTracks)
    }
}
