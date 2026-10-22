import Foundation

enum ArtworkCache {
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Melody/Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func url(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("img")
    }

    static func save(_ data: Data, for id: UUID) {
        try? data.write(to: url(for: id), options: .atomic)
    }

    static func load(for id: UUID) -> Data? {
        try? Data(contentsOf: url(for: id))
    }

    static func delete(for id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }
}
