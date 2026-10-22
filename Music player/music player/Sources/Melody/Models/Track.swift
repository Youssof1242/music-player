import Foundation

struct Track: Identifiable, Codable, Sendable {
    let id: UUID
    let url: URL
    var title: String
    var artist: String
    var album: String
    var duration: Double
    let dateAdded: Date
    var artworkData: Data?

    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        artist: String,
        album: String,
        duration: Double,
        dateAdded: Date = Date(),
        artworkData: Data? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.dateAdded = dateAdded
        self.artworkData = artworkData
    }

    private enum CodingKeys: String, CodingKey {
        case id, url, title, artist, album, duration, dateAdded
    }
}

extension Track: Hashable {
    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Playlist: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    var trackIDs: [UUID] = []
    var dateCreated: Date = Date()
}

enum RepeatMode: String, CaseIterable, Codable, Sendable {
    case off
    case all
    case one

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    var symbolName: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    var label: String {
        switch self {
        case .off: return "Repeat Off"
        case .all: return "Repeat All"
        case .one: return "Repeat One"
        }
    }
}

func formattedTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let total = Int(seconds.rounded())
    let minutes = total / 60
    let secs = total % 60
    if minutes >= 60 {
        return String(format: "%d:%02d:%02d", minutes / 60, minutes % 60, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}
