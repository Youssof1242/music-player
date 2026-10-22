import AppKit
import UniformTypeIdentifiers

enum ImportPanel {
    @MainActor
    static func chooseFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = audioContentTypes
        panel.prompt = "Add"
        panel.message = "Choose audio files to add to your library"
        return panel.runModal() == .OK ? panel.urls : []
    }

    @MainActor
    static func chooseFolder() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose a folder of music"
        return panel.runModal() == .OK ? panel.urls : []
    }

    private static var audioContentTypes: [UTType] {
        var types: [UTType] = [.audio]
        for ext in MetadataLoader.supportedExtensions {
            if let type = UTType(filenameExtension: ext), !types.contains(type) {
                types.append(type)
            }
        }
        return types
    }
}
