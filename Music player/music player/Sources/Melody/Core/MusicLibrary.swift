import Foundation

struct LibrarySnapshot: Codable {
    var tracks: [Track]
    var playlists: [Playlist]
    var favoriteIDs: [UUID]
}

@MainActor
final class MusicLibrary: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var favoriteIDs: Set<UUID> = []
    @Published private(set) var isImporting = false
    @Published private(set) var importStatusText: String?

    private let storageDirectory: URL
    private var clearStatusTask: Task<Void, Never>?

    private var libraryFile: URL {
        storageDirectory.appendingPathComponent("library.json")
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = base.appendingPathComponent("Melody", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: libraryFile),
              let snapshot = try? JSONDecoder().decode(LibrarySnapshot.self, from: data) else {
            return
        }
        let existing = snapshot.tracks.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        tracks = existing
        let validIDs = Set(existing.map(\.id))
        playlists = snapshot.playlists.map { playlist in
            var copy = playlist
            copy.trackIDs = playlist.trackIDs.filter { validIDs.contains($0) }
            return copy
        }
        favoriteIDs = Set(snapshot.favoriteIDs).intersection(validIDs)
    }

    func save() {
        let snapshot = LibrarySnapshot(
            tracks: tracks,
            playlists: playlists,
            favoriteIDs: Array(favoriteIDs)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: libraryFile, options: .atomic)
    }

    // MARK: - Import

    func importURLs(_ urls: [URL]) {
        let candidates = Self.collectAudioFiles(from: urls)
        guard !candidates.isEmpty else {
            showStatus("No audio files found to import")
            return
        }

        var seen = Set(tracks.map { $0.url.standardizedFileURL.path })
        let newFiles = candidates.filter { url in
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }

        guard !newFiles.isEmpty else {
            showStatus("All selected songs are already in your library")
            return
        }

        isImporting = true
        importStatusText = "Importing \(newFiles.count) file\(newFiles.count == 1 ? "" : "s")…"

        Task {
            let imported = await Self.processFiles(newFiles)
            tracks.append(contentsOf: imported)
            isImporting = false
            save()
            showStatus("Added \(imported.count) song\(imported.count == 1 ? "" : "s") to your library")
        }
    }

    nonisolated private static func processFiles(_ files: [URL]) async -> [Track] {
        var results: [Track] = []
        let maxConcurrent = 4

        await withTaskGroup(of: Track?.self) { group in
            var next = 0

            func addTask(for url: URL) {
                group.addTask { await makeTrack(from: url) }
            }

            while next < files.count && next < maxConcurrent {
                addTask(for: files[next])
                next += 1
            }

            while let track = await group.next() {
                if let track { results.append(track) }
                if next < files.count {
                    addTask(for: files[next])
                    next += 1
                }
            }
        }

        return results.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    nonisolated private static func makeTrack(from url: URL) async -> Track? {
        guard let metadata = await MetadataLoader.load(url: url) else { return nil }
        let id = UUID()
        if let artwork = metadata.artworkData {
            ArtworkCache.save(artwork, for: id)
        }
        return Track(
            id: id,
            url: url,
            title: metadata.title,
            artist: metadata.artist,
            album: metadata.album,
            duration: metadata.duration,
            artworkData: metadata.artworkData
        )
    }

    nonisolated private static func collectAudioFiles(from urls: [URL]) -> [URL] {
        let fileManager = FileManager.default
        var result: [URL] = []

        for url in urls {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }

            if isDirectory.boolValue {
                let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
                while let fileURL = enumerator?.nextObject() as? URL {
                    if MetadataLoader.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                        result.append(fileURL)
                    }
                }
            } else if MetadataLoader.supportedExtensions.contains(url.pathExtension.lowercased()) {
                result.append(url)
            }
        }
        return result
    }

    private func showStatus(_ text: String) {
        importStatusText = text
        clearStatusTask?.cancel()
        clearStatusTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.importStatusText = nil
        }
    }

    // MARK: - Mutations

    func remove(_ track: Track) {
        tracks.removeAll { $0.id == track.id }
        favoriteIDs.remove(track.id)
        for index in playlists.indices {
            playlists[index].trackIDs.removeAll { $0 == track.id }
        }
        ArtworkCache.delete(for: track.id)
        save()
    }

    func isFavorite(_ track: Track) -> Bool {
        favoriteIDs.contains(track.id)
    }

    func setFavorite(_ track: Track, _ value: Bool) {
        if value {
            favoriteIDs.insert(track.id)
        } else {
            favoriteIDs.remove(track.id)
        }
        save()
    }

    @discardableResult
    func createPlaylist(named name: String) -> Playlist {
        let playlist = Playlist(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        playlists.append(playlist)
        save()
        return playlist
    }

    func renamePlaylist(_ id: UUID, to name: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        playlists[index].name = trimmed
        save()
    }

    func deletePlaylist(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        save()
    }

    func add(_ track: Track, toPlaylist id: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        guard !playlists[index].trackIDs.contains(track.id) else { return }
        playlists[index].trackIDs.append(track.id)
        save()
    }

    func remove(_ track: Track, fromPlaylist id: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].trackIDs.removeAll { $0 == track.id }
        save()
    }
}
