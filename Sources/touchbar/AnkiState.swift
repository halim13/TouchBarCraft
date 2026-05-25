import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
public final class AnkiState {
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
    
    private var connectionCheckTimer: Timer?
    
    public init() {
        Self.shared = self
        startConnectionMonitor()
    }
    
    // MARK: - Connection
    
    private func startConnectionMonitor() {
        // Check connection every 5 seconds
        checkConnection()
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkConnection()
            }
        }
    }
    
    public func checkConnection() {
        Task {
            let connected = await AnkiConnectClient.shared.isConnected()
            self.isConnected = connected
            if connected {
                self.connectionError = ""
            } else {
                self.connectionError = "Anki tidak terbuka atau AnkiConnect belum terinstal"
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
        let widget = getActiveAnkiWidget()
        let qField = widget?.ankiQuestionField ?? "Front"
        let aField = widget?.ankiAnswerField ?? "Back"
        
        let card = await AnkiConnectClient.shared.getCurrentCard(questionField: qField, answerField: aField)
        self.currentCard = card
        self.isShowingAnswer = false
        self.isLoading = false
        
        if card != nil {
            await AnkiConnectClient.shared.startCardTimer()
        }
        
        // Refresh touch bar to show new card
        refreshTouchBar()
    }
    
    /// Reveal the answer for the current card
    public func revealAnswer() {
        guard currentCard != nil else { return }
        
        Task {
            let shown = await AnkiConnectClient.shared.showAnswer()
            if shown {
                self.isShowingAnswer = true
                refreshTouchBar()
            }
        }
    }
    
    /// Submit a rating and advance to the next card
    /// ease: 1=Again, 2=Hard, 3=Good, 4=Easy
    public func submitRating(ease: Int) {
        guard currentCard != nil, isShowingAnswer else { return }
        
        self.isLoading = true
        
        Task {
            let answered = await AnkiConnectClient.shared.answerCard(ease: ease)
            if answered {
                self.cardsReviewed += 1
                await loadCurrentCard()
            } else {
                self.isLoading = false
                self.connectionError = "Gagal mengirim rating"
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
}
