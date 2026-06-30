import Foundation
import SwiftUI
import Observation
import AVFoundation

public enum NHKNewsMode: Sendable {
    case articleList
    case reading
}

@Observable
@MainActor
public final class NHKNewsState {
    public static var shared: NHKNewsState?

    public var articles: [NHKNewsArticle] = []
    public var isLoading: Bool = false
    public var errorMessage: String = ""
    public var lastUpdated: Date?

    public var mode: NHKNewsMode = .articleList
    public var currentArticleIndex: Int = 0
    public var currentChunkIndex: Int = 0

    private var cacheTimer: Timer?
    private let cacheInterval: TimeInterval = 1800

    public init() {
        Self.shared = self
        startAutoRefresh()
    }

    public var currentArticle: NHKNewsArticle? {
        guard !articles.isEmpty, currentArticleIndex < articles.count else { return nil }
        return articles[currentArticleIndex]
    }

    public var currentChunk: String {
        guard let article = currentArticle else { return "" }
        if article.contentChunks.isEmpty { return article.description }
        guard currentChunkIndex < article.contentChunks.count else { return article.description }
        return article.contentChunks[currentChunkIndex]
    }

    public var chunkProgress: String {
        guard let article = currentArticle, !article.contentChunks.isEmpty else { return "" }
        return "\(currentChunkIndex + 1)/\(article.contentChunks.count)"
    }

    public var hasChunks: Bool {
        guard let article = currentArticle else { return false }
        return !article.contentChunks.isEmpty
    }

    public func fetchArticles() async {
        isLoading = true
        errorMessage = ""
        do {
            let fetched = try await NHKEasyNewsAPI.shared.fetchArticleList()
            self.articles = fetched.map { $0.cleaningFooterChunks() }
            self.lastUpdated = Date()
            self.currentArticleIndex = 0
            self.currentChunkIndex = 0
            self.mode = .articleList
        } catch {
            self.errorMessage = "Failed to load news: \(error.localizedDescription)"
            print("NHKNewsState: \(self.errorMessage)")
        }
        isLoading = false
        // Refresh the physical Touch Bar to show the updated article list
        refreshTouchBar()
    }

    public func nextArticle() {
        guard !articles.isEmpty else { return }
        currentArticleIndex = (currentArticleIndex + 1) % articles.count
        currentChunkIndex = 0
        mode = .articleList
        refreshTouchBar()
    }

    public func previousArticle() {
        guard !articles.isEmpty else { return }
        currentArticleIndex = (currentArticleIndex - 1 + articles.count) % articles.count
        currentChunkIndex = 0
        mode = .articleList
        refreshTouchBar()
    }

    public func startReading() {
        guard currentArticle != nil else { return }
        currentChunkIndex = 0
        mode = .reading
        refreshTouchBar()
    }

    public func nextChunk() {
        guard let article = currentArticle, !article.contentChunks.isEmpty else { return }
        if currentChunkIndex < article.contentChunks.count - 1 {
            currentChunkIndex += 1
        } else {
            currentChunkIndex = 0
        }
        refreshTouchBar()
    }

    public func previousChunk() {
        guard !(currentArticle?.contentChunks.isEmpty ?? true) else { return }
        if currentChunkIndex > 0 {
            currentChunkIndex -= 1
        } else {
            currentChunkIndex = (currentArticle?.contentChunks.count ?? 1) - 1
        }
        refreshTouchBar()
    }

    public func returnToList() {
        mode = .articleList
        currentChunkIndex = 0
        refreshTouchBar()
    }

    // MARK: - Audio Playback

    private var audioPlayer: AVAudioPlayer?
    private var audioDelegate: AudioDelegate?
    public private(set) var isAudioPlaying = false

    public var isAudioAvailable: Bool {
        currentArticle?.audioURL != nil
    }

    public func playPauseAudio() {
        if let player = audioPlayer, player.isPlaying {
            player.pause()
            isAudioPlaying = false
        } else if let player = audioPlayer {
            player.play()
            isAudioPlaying = true
        } else if let url = currentArticle?.audioURL {
            Task {
                await loadAndPlayAudio(url: url)
            }
        }
    }

    public func stopAudio() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        audioPlayer = nil
        audioDelegate = nil
        isAudioPlaying = false
    }

    private func loadAndPlayAudio(url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let player = try AVAudioPlayer(data: data)
            let delegate = AudioDelegate { [weak self] in
                Task { @MainActor in
                    self?.audioPlayer = nil
                    self?.audioDelegate = nil
                    self?.isAudioPlaying = false
                    self?.refreshTouchBar()
                }
            }
            player.delegate = delegate
            self.audioDelegate = delegate
            player.prepareToPlay()
            self.audioPlayer = player
            player.play()
            self.isAudioPlaying = true
        } catch {
            print("NHKNewsState: Failed to load/play audio: \(error)")
        }
    }

    private final class AudioDelegate: NSObject, AVAudioPlayerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            onFinish()
        }
    }

    private func refreshTouchBar() {
        // Always refresh floating window content
        NHKFloatingWindowManager.shared.refreshContent()

        // If all NHK widgets are hidden from the physical Touch Bar, skip Touch Bar refresh
        if let widgets = AppState.shared?.widgets {
            let nhkWidgets = widgets.filter { $0.type == .nhkNews }
            if !nhkWidgets.isEmpty && nhkWidgets.allSatisfy({ $0.hideFromTouchBar }) {
                return
            }
        }
        let presenterClass: AnyClass? = NSClassFromString("touchbar.TouchBarPresenter")
        let refreshSelector = NSSelectorFromString("updateNHKContent")
        if let presenter = presenterClass as? NSObject.Type {
            presenter.perform(refreshSelector)
        }
    }

    private func startAutoRefresh() {
        cacheTimer = Timer.scheduledTimer(withTimeInterval: cacheInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchArticles()
            }
        }
    }

    public func stopAutoRefresh() {
        cacheTimer?.invalidate()
        cacheTimer = nil
    }
}
