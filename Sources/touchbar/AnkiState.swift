import Foundation
import SwiftUI
import Observation
import AppKit
import AVFoundation

@Observable
@MainActor
public final class AnkiState: NSObject, AVAudioPlayerDelegate {
    public static var shared: AnkiState? = nil
    
    // Connection
    public var isConnected: Bool = false
    public var connectionError: String = ""
    
    // Deck management
    public var deckNames: [String] = []
    public var selectedDeck: String = ""
    
    // Card state
    public var currentCard: AnkiCard? = nil
    public var isShowingAnswer: Bool = false
    public var isLoading: Bool = false
    public var isSyncing: Bool = false
    
    // Stats
    public var cardsReviewed: Int = 0
    public var sessionStartTime: Date? = nil
    
    // Remaining Card Counts
    public var newCount: Int = 0
    public var learnCount: Int = 0
    public var reviewCount: Int = 0
    
    // Audio
    public var isMuted: Bool = false
    public var isAudioPlaying: Bool = false
    private var currentSound: AVAudioPlayer? = nil
    public var isTouchBarAudioPlaying: Bool = false
    private var currentTouchBarSound: AVAudioPlayer? = nil
    
    /// When muted, guiShowAnswer is skipped on reveal to prevent Anki from playing audio natively.
    /// This flag ensures guiShowAnswer is called right before guiAnswerCard on rating.
    private var needsGuiShowAnswer: Bool = false
    
    private var connectionCheckTimer: Timer?
    private var wasConnectedBefore: Bool = false
    private var hasRestoredDeck: Bool = false
    
    public override init() {
        super.init()
        Self.shared = self
        startConnectionMonitor()
    }
    
    // MARK: - Connection
    
    private func startConnectionMonitor() {
        // Check connection every 10 seconds (reduced from 5 to avoid flickering)
        checkConnectionSilent()
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkConnectionSilent()
            }
        }
    }
    
    /// Silent connection check — only updates status, does NOT restart review
    private func checkConnectionSilent() {
        Task {
            let connected = await AnkiConnectClient.shared.isConnected()
            let justConnected = connected && !wasConnectedBefore
            self.isConnected = connected
            self.wasConnectedBefore = connected
            
            if connected {
                self.connectionError = ""
                // Only restore deck on first connection, not every poll
                if justConnected && !hasRestoredDeck {
                    hasRestoredDeck = true
                    fetchDecks()
                    let widget = getActiveAnkiWidget()
                    if let deckName = widget?.ankiDeckName, !deckName.isEmpty {
                        self.selectedDeck = deckName
                        startReview(deck: deckName)
                    }
                }
            } else {
                self.connectionError = "Anki tidak terbuka atau AnkiConnect belum terinstal"
                self.hasRestoredDeck = false // Reset so we restore next time we connect
            }
        }
    }
    
    /// Manual connect button — always tries to restore deck
    public func checkConnection() {
        Task {
            let connected = await AnkiConnectClient.shared.isConnected()
            self.isConnected = connected
            self.wasConnectedBefore = connected
            if connected {
                self.connectionError = ""
                fetchDecks()
                let widget = getActiveAnkiWidget()
                if let deckName = widget?.ankiDeckName, !deckName.isEmpty {
                    self.selectedDeck = deckName
                    hasRestoredDeck = true
                    startReview(deck: deckName)
                }
            } else {
                // Try to launch Anki application!
                if let ankiURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.ankiweb.dtop") ??
                                 NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.ichi2.anki") {
                    let config = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.openApplication(at: ankiURL, configuration: config) { _, error in
                        if let error = error {
                            print("Gagal membuka Anki: \(error.localizedDescription)")
                        }
                    }
                } else {
                    // Fallback to open -a Anki command
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    process.arguments = ["-a", "Anki"]
                    try? process.run()
                }
                self.connectionError = "Membuka Anki... Klik Connect lagi setelah aplikasi Anki terbuka."
            }
        }
    }
    
    // MARK: - Deck Management
    
    public func fetchDecks() {
        Task {
            let decks = await AnkiConnectClient.shared.getDeckNames()
            self.deckNames = decks.sorted()
            if !decks.isEmpty && self.selectedDeck.isEmpty {
                self.selectedDeck = decks.first ?? ""
            }
        }
    }
    
    // MARK: - Review Flow
    
    /// Start reviewing a specific deck
    public func startReview(deck: String) {
        guard !deck.isEmpty else { return }
        self.selectedDeck = deck
        self.isLoading = true
        self.isShowingAnswer = false
        self.cardsReviewed = 0
        self.sessionStartTime = Date()
        
        Task {
            let started = await AnkiConnectClient.shared.startDeckReview(name: deck)
            if started {
                await loadCurrentCard()
            } else {
                self.isLoading = false
                self.connectionError = "Gagal memulai review deck '\(deck)'"
            }
        }
    }
    
    private func getActiveAnkiWidget() -> TouchBarWidget? {
        guard let state = AppState.shared else { return nil }
        if let selectedID = state.selectedWidgetID,
           let widget = state.widgets.first(where: { $0.id == selectedID }),
           widget.type == .anki {
            return widget
        }
        return state.widgets.first(where: { $0.type == .anki })
    }
    
    /// Load the current card from Anki
    public func loadCurrentCard() async {
        self.isLoading = true
        stopAudio()
        stopTouchBarAudio()
        let widget = getActiveAnkiWidget()
        let qField = widget?.ankiQuestionField ?? "Front"
        let aField = widget?.ankiAnswerField ?? "Back"
        let audioField = widget?.ankiAudioField ?? "Audio"
        let touchBarAudioField = widget?.ankiTouchBarAudioField ?? audioField
        
        let card = await AnkiConnectClient.shared.getCurrentCard(questionField: qField, answerField: aField, audioField: audioField, touchBarAudioField: touchBarAudioField)
        self.currentCard = card
        self.isShowingAnswer = false
        self.needsGuiShowAnswer = false
        self.isLoading = false
        
        if let card = card {
            if let stats = await AnkiConnectClient.shared.getDeckStats(name: card.deckName) {
                self.newCount = stats.newCount
                self.learnCount = stats.learnCount
                self.reviewCount = stats.reviewCount
            } else {
                self.newCount = 0
                self.learnCount = 0
                self.reviewCount = 0
            }
            await AnkiConnectClient.shared.startCardTimer()
        } else {
            self.newCount = 0
            self.learnCount = 0
            self.reviewCount = 0
        }
        
        // Refresh touch bar and system tray menu to show new card
        refreshTouchBar()
        StatusItemManager.shared.refreshAnkiCardInfo()
    }
    
    /// Reveal the answer for the current card
    public func revealAnswer() {
        guard currentCard != nil else { return }
        
        self.isShowingAnswer = true
        refreshTouchBar()
        StatusItemManager.shared.refreshAnkiCardInfo()
        
        Task {
            if isMuted {
                // Saat mute aktif, skip guiShowAnswer agar Anki tidak memutar audio secara native.
                // Tandai bahwa guiShowAnswer perlu dipanggil sebelum guiAnswerCard nanti.
                needsGuiShowAnswer = true
            } else {
                needsGuiShowAnswer = false  // pastikan tidak ada stale flag
                // Panggil guiShowAnswer agar state Anki tetap sinkron
                // (diperlukan agar guiAnswerCard berfungsi saat user menekan rating).
                let shown = await AnkiConnectClient.shared.showAnswer()
                if !shown {
                    // Jika gagal, reset isShowingAnswer agar user bisa coba lagi
                    self.isShowingAnswer = false
                    refreshTouchBar()
                    StatusItemManager.shared.refreshAnkiCardInfo()
                }
            }
            await AnkiConnectClient.shared.startCardTimer()
        }
    }
    
    /// Submit a rating and advance to the next card
    /// ease: 1=Again, 2=Hard, 3=Good, 4=Easy
    public func submitRating(ease: Int) {
        guard currentCard != nil, isShowingAnswer else { return }
        
        self.isLoading = true
        stopAudio()
        stopTouchBarAudio()
        
        Task {
            if needsGuiShowAnswer {
                // Jika reveal sebelumnya di-skip karena mute, panggil guiShowAnswer
                // sekarang agar guiAnswerCard bisa berfungsi.
                _ = await AnkiConnectClient.shared.showAnswer()
                needsGuiShowAnswer = false
            }
            
            let answered = await AnkiConnectClient.shared.answerCard(ease: ease)
            if answered {
                self.cardsReviewed += 1
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms delay
                await loadCurrentCard()
            } else {
                self.isLoading = false
                self.connectionError = "Gagal mengirim rating"
                StatusItemManager.shared.refreshAnkiCardInfo()
            }
        }
    }
    
    /// Sync deck updates with AnkiWeb
    public func syncDecks() {
        self.isSyncing = true
        self.isLoading = true
        refreshTouchBar()
        
        Task {
            let success = await AnkiConnectClient.shared.sync()
            self.isSyncing = false
            self.isLoading = false
            if success {
                self.connectionError = ""
                fetchDecks()
                await loadCurrentCard()
            } else {
                self.connectionError = "Gagal melakukan sinkronisasi dengan AnkiWeb"
                refreshTouchBar()
            }
        }
    }
    
    // MARK: - Touch Bar Refresh
    
    public func refreshTouchBar() {
        let presenterClass: AnyClass? = NSClassFromString("touchbar.TouchBarPresenter")
        let refreshSelector = NSSelectorFromString("refreshTouchBar")
        if let presenter = presenterClass as? NSObject.Type {
            presenter.perform(refreshSelector)
        }
    }
    
    // MARK: - Helpers
    
    public var sessionDuration: String {
        guard let start = sessionStartTime else { return "0m" }
        let elapsed = Int(Date().timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
    
    public var questionPreview: String {
        currentCard?.question ?? "Waiting for card..."
    }
    
    public var answerPreview: String {
        currentCard?.answer ?? ""
    }
    
    // MARK: - Audio Controls
    
    public func toggleMute() {
        isMuted.toggle()
        if isMuted {
            // Hentikan audio langsung tanpa refreshTouchBar() agar tidak
            // mengganggu layout Touch Bar (stopAudio/stopTouchBarAudio memicu refresh)
            currentSound?.stop()
            currentSound = nil
            isAudioPlaying = false
            currentTouchBarSound?.stop()
            currentTouchBarSound = nil
            isTouchBarAudioPlaying = false
        }
    }
    
    public func toggleAudio() {
        if isAudioPlaying {
            stopAudio()
        } else {
            playAudio()
        }
    }
    
    public func stopAudio() {
        currentSound?.stop()
        currentSound = nil
        isAudioPlaying = false
        // refreshTouchBar()
    }
    
    public func stopTouchBarAudio() {
        currentTouchBarSound?.stop()
        currentTouchBarSound = nil
        isTouchBarAudioPlaying = false
        // refreshTouchBar()
    }
    
    public func toggleTouchBarAudio() {
        if isTouchBarAudioPlaying {
            stopTouchBarAudio()
        } else {
            playTouchBarAudio()
        }
    }
    
    public func playTouchBarAudio() {
        guard !isMuted, let card = currentCard, let filename = card.touchBarSoundFilename else { return }
        
        // Jika audioOnlyOnAnswer aktif dan answer belum ditampilkan, jangan play
        if let widget = getActiveAnkiWidget(), widget.ankiAudioOnlyOnAnswer, !isShowingAnswer {
            print("AnkiState: Touch Bar audio ditahan karena answer belum direveal (audioOnlyOnAnswer aktif)")
            return
        }
        
        // Stop currently playing sound if any
        currentTouchBarSound?.stop()
        currentTouchBarSound = nil
        isTouchBarAudioPlaying = false
        
        Task {
            if let data = await AnkiConnectClient.shared.retrieveMediaFile(filename: filename) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try data.write(to: tempURL)
                    
                    await MainActor.run {
                        do {
                            let sound = try AVAudioPlayer(contentsOf: tempURL)
                            sound.delegate = self
                            self.currentTouchBarSound = sound
                            self.isTouchBarAudioPlaying = true
                            sound.play()
                            // self.refreshTouchBar()
                        } catch {
                            print("AnkiState: Failed to play Touch Bar audio using AVAudioPlayer: \(error)")
                        }
                    }
                } catch {
                    print("AnkiState: Failed to write temp Touch Bar audio file: \(error)")
                }
            }
        }
    }
    
    public func playAudio() {
        guard !isMuted, let card = currentCard, let filename = card.soundFilename else { return }
        
        // Jika audioOnlyOnAnswer aktif dan answer belum ditampilkan, jangan play
        if let widget = getActiveAnkiWidget(), widget.ankiAudioOnlyOnAnswer, !isShowingAnswer {
            print("AnkiState: Audio ditahan karena answer belum direveal (audioOnlyOnAnswer aktif)")
            return
        }
        
        // Stop currently playing sound if any
        currentSound?.stop()
        currentSound = nil
        isAudioPlaying = false
        
        Task {
            if let data = await AnkiConnectClient.shared.retrieveMediaFile(filename: filename) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try data.write(to: tempURL)
                    
                    await MainActor.run {
                        do {
                            let sound = try AVAudioPlayer(contentsOf: tempURL)
                            sound.delegate = self
                            self.currentSound = sound
                            self.isAudioPlaying = true
                            sound.play()
                            // self.refreshTouchBar()
                        } catch {
                            print("AnkiState: Failed to play audio using AVAudioPlayer: \(error)")
                        }
                    }
                } catch {
                    print("AnkiState: Failed to write temp audio file: \(error)")
                }
            }
        }
    }
    
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Use ObjectIdentifier to safely compare player identity across actor boundaries
        let playerId = ObjectIdentifier(player)
        Task { @MainActor in
            if let tbSound = self.currentTouchBarSound, ObjectIdentifier(tbSound) == playerId {
                self.isTouchBarAudioPlaying = false
                self.currentTouchBarSound = nil
            } else {
                self.isAudioPlaying = false
                self.currentSound = nil
            }
            // self.refreshTouchBar()
        }
    }
}
