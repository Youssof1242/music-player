import Foundation
import AVFoundation

enum MetadataLoader {
    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "m4b", "aac", "wav", "aiff", "aif", "caf", "flac", "alac"
    ]

    struct Loaded: Sendable {
        var title: String
        var artist: String
        var album: String
        var duration: Double
        var artworkData: Data?
    }

    static func load(url: URL) async -> Loaded? {
        let asset = AVURLAsset(url: url)
        let fallbackTitle = url.deletingPathExtension().lastPathComponent

        var duration: Double = 0
        if let cmTime = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(cmTime)
            if seconds.isFinite && seconds > 0 { duration = seconds }
        }

        var title: String?
        var artist: String?
        var album: String?
        var artwork: Data?

        if let commonItems = try? await asset.load(.commonMetadata) {
            for item in commonItems {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    title = (try? await item.load(.stringValue)) ?? nil
                case .commonKeyArtist:
                    artist = (try? await item.load(.stringValue)) ?? nil
                case .commonKeyAlbumName:
                    album = (try? await item.load(.stringValue)) ?? nil
                case .commonKeyArtwork:
                    artwork = (try? await item.load(.dataValue)) ?? nil
                default:
                    break
                }
            }
        }

        if let items = try? await asset.load(.metadata) {
            if title == nil, let item = firstItem(in: items, matching: [
                .iTunesMetadataSongName, .id3MetadataTitleDescription, .quickTimeMetadataTitle
            ]) {
                title = (try? await item.load(.stringValue)) ?? nil
            }
            if artist == nil, let item = firstItem(in: items, matching: [
                .iTunesMetadataArtist, .id3MetadataOriginalArtist, .id3MetadataLeadPerformer, .quickTimeMetadataArtist
            ]) {
                artist = (try? await item.load(.stringValue)) ?? nil
            }
            if album == nil, let item = firstItem(in: items, matching: [
                .iTunesMetadataAlbum, .id3MetadataAlbumTitle, .quickTimeMetadataAlbum
            ]) {
                album = (try? await item.load(.stringValue)) ?? nil
            }
            if artwork == nil, let item = firstItem(in: items, matching: [
                .iTunesMetadataCoverArt, .id3MetadataAttachedPicture, .quickTimeMetadataArtwork
            ]) {
                artwork = (try? await item.load(.dataValue)) ?? nil
            }
        }

        return Loaded(
            title: title?.trimmedNonEmpty ?? fallbackTitle,
            artist: artist?.trimmedNonEmpty ?? "Unknown Artist",
            album: album?.trimmedNonEmpty ?? "Unknown Album",
            duration: duration,
            artworkData: artwork
        )
    }

    private static func firstItem(in items: [AVMetadataItem], matching identifiers: [AVMetadataIdentifier]) -> AVMetadataItem? {
        for identifier in identifiers {
            if let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier).first {
                return item
            }
        }
        return nil
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
