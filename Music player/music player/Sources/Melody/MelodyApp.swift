import SwiftUI
import AppKit

@main
struct MelodyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var library = MusicLibrary()
    @StateObject private var player = PlayerEngine()

    var body: some Scene {
        WindowGroup("Melody") {
            ContentView()
                .environmentObject(library)
                .environmentObject(player)
                .onAppear {
                    appDelegate.library = library
                    appDelegate.flushPendingImports()
                    NowPlaying.shared.configure(with: player)
                }
        }
        .defaultSize(width: 1150, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Files…") {
                    library.importURLs(ImportPanel.chooseFiles())
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Import Folder…") {
                    library.importURLs(ImportPanel.chooseFolder())
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandMenu("Playback") {
                Button(player.isPlaying ? "Pause" : "Play") {
                    player.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(player.currentTrack == nil && player.isQueueEmpty)

                Button("Next Track") {
                    player.next()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(player.currentTrack == nil)

                Button("Previous Track") {
                    player.previous()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(player.currentTrack == nil)

                Divider()

                Button(player.isShuffled ? "Shuffle: On" : "Shuffle: Off") {
                    player.isShuffled.toggle()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button(player.repeatMode.label) {
                    player.repeatMode = player.repeatMode.next
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Increase Volume") {
                    player.volume = min(player.volume + 0.05, 1)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                Button("Decrease Volume") {
                    player.volume = max(player.volume - 0.05, 0)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var library: MusicLibrary?
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let library {
            library.importURLs(urls)
        } else {
            pendingURLs.append(contentsOf: urls)
        }
    }

    func flushPendingImports() {
        guard !pendingURLs.isEmpty else { return }
        let urls = pendingURLs
        pendingURLs = []
        library?.importURLs(urls)
    }
}
