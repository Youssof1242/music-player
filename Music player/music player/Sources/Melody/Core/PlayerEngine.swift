import Foundation
import AVFoundation

@MainActor
final class PlayerEngine: NSObject, ObservableObject {
    @Published private(set) var currentTrack: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var errorMessage: String?

    @Published var volume: Double = 0.8 {
        didSet { audioPlayer?.volume = Float(volume) }
    }

    @Published var isShuffled = false {
        didSet { rebuildOrder(preservingCurrent: true) }
    }

    @Published var repeatMode: RepeatMode = .off

    private var audioPlayer: AVAudioPlayer?
    private var queue: [Track] = []
    private var order: [Int] = []
    private var position = 0
    private var progressTask: Task<Void, Never>?

    var isQueueEmpty: Bool { queue.isEmpty }

    func play(_ track: Track, in tracks: [Track]) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            if queue.map(\.id) != tracks.map(\.id) {
                queue = tracks
                rebuildOrder(preservingCurrent: false)
                position = order.firstIndex(of: index) ?? 0
            } else if let pos = order.firstIndex(of: index) {
                position = pos
            }
        } else {
            queue = [track]
            rebuildOrder(preservingCurrent: false)
            position = 0
        }
        loadAndPlay(track)
    }

    func playNext(_ track: Track) {
        if queue.isEmpty {
            play(track, in: [track])
            return
        }
        guard track.id != currentTrack?.id else { return }

        let queueIndex: Int
        if let existing = queue.firstIndex(where: { $0.id == track.id }) {
            let wasBeforeCurrent = order.firstIndex(of: existing).map { $0 < position } ?? false
            order.removeAll { $0 == existing }
            if wasBeforeCurrent { position = max(position - 1, 0) }
            queueIndex = existing
        } else {
            queue.append(track)
            queueIndex = queue.count - 1
        }
        order.insert(queueIndex, at: min(position + 1, order.count))
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        guard let player = audioPlayer else {
            if let currentTrack {
                loadAndPlay(currentTrack)
            } else if let first = queue.first {
                play(first, in: queue)
            }
            return
        }
        player.play()
        isPlaying = true
        startProgressUpdates()
        NowPlaying.shared.update(track: currentTrack, isPlaying: true, elapsed: player.currentTime)
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        progressTask?.cancel()
        NowPlaying.shared.update(track: currentTrack, isPlaying: false, elapsed: audioPlayer?.currentTime ?? currentTime)
    }

    func seek(to time: Double) {
        guard let player = audioPlayer else { return }
        let clamped = min(max(time, 0), player.duration)
        player.currentTime = clamped
        currentTime = clamped
        NowPlaying.shared.update(track: currentTrack, isPlaying: isPlaying, elapsed: clamped)
    }

    func next(userInitiated: Bool = true) {
        guard !queue.isEmpty else { return }
        if !userInitiated, repeatMode == .one, let currentTrack {
            loadAndPlay(currentTrack)
            return
        }
        if position + 1 < order.count {
            position += 1
            loadAndPlay(queue[order[position]])
        } else if repeatMode == .all {
            if isShuffled {
                rebuildOrder(preservingCurrent: false)
            }
            position = 0
            loadAndPlay(queue[order[position]])
        } else if userInitiated {
            seek(to: 0)
        } else {
            stopAtEndOfQueue()
        }
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        if position > 0 {
            position -= 1
            loadAndPlay(queue[order[position]])
        } else if repeatMode == .all, !order.isEmpty {
            position = order.count - 1
            loadAndPlay(queue[order[position]])
        } else {
            seek(to: 0)
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        progressTask?.cancel()
        currentTrack = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        NowPlaying.shared.update(track: nil, isPlaying: false, elapsed: 0)
    }

    private func loadAndPlay(_ track: Track) {
        do {
            let player = try AVAudioPlayer(contentsOf: track.url)
            player.delegate = self
            player.volume = Float(volume)
            player.prepareToPlay()

            audioPlayer = player
            currentTrack = track
            duration = player.duration
            currentTime = 0
            player.play()
            isPlaying = true
            startProgressUpdates()
            NowPlaying.shared.update(track: track, isPlaying: true, elapsed: 0)
        } catch {
            isPlaying = false
            errorMessage = "Couldn't play \"\(track.title)\". \(error.localizedDescription)"
        }
    }

    private func stopAtEndOfQueue() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        progressTask?.cancel()
        NowPlaying.shared.update(track: currentTrack, isPlaying: false, elapsed: 0)
    }

    private func startProgressUpdates() {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        guard let player = audioPlayer, isPlaying else { return }
        currentTime = player.currentTime
    }

    private func rebuildOrder(preservingCurrent: Bool) {
        guard !queue.isEmpty else {
            order = []
            position = 0
            return
        }

        if isShuffled {
            var indices = Array(0..<queue.count)
            if preservingCurrent, !order.isEmpty, position < order.count {
                let currentIndex = order[position]
                indices.removeAll { $0 == currentIndex }
                indices.shuffle()
                indices.insert(currentIndex, at: 0)
                order = indices
                position = 0
            } else {
                indices.shuffle()
                order = indices
                position = 0
            }
        } else {
            let currentIndex = (preservingCurrent && position < order.count) ? order[position] : nil
            order = Array(0..<queue.count)
            if let currentIndex, let index = order.firstIndex(of: currentIndex) {
                position = index
            } else {
                position = min(position, max(order.count - 1, 0))
            }
        }
    }

    fileprivate func handleFinishedPlaying() {
        next(userInitiated: false)
    }
}

extension PlayerEngine: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.handleFinishedPlaying()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.handleFinishedPlaying()
        }
    }
}
