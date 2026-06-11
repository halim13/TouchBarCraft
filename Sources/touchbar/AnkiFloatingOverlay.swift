import SwiftUI
import AppKit

// MARK: - Floating Overlay Configuration
// Stored in UserDefaults so it's separate from widget configuration
public struct AnkiFloatingOverlayConfig: Codable, Sendable {
    public var isEnabled: Bool
    public var fontSize: Double
    public var windowOpacity: Double
    public var textOpacity: Double
    public var windowWidth: Double
    public var windowHeight: Double
    public var showRatingButtons: Bool
    public var showAudioButton: Bool
    public var showSyncButton: Bool
    public var showRevealButton: Bool
    public var overlayFuriganaFontSize: Double
    public var hideTitleBar: Bool
    public var textColorHex: String
    public var backgroundColorHex: String
    public var questionAnswerColorHex: String
    public var showHeader: Bool
    public var showCounts: Bool
    public var positionX: Double
    public var positionY: Double
    public var extraQuestionField: String  // Additional question field for overlay (comma-separated)
    public var extraAnswerField: String    // Additional answer field for overlay (comma-separated)
    public var extraQuestionOnlyOnAnswer: Bool // Show extra question field only on answer phase
    public var extraFieldColorHex: String  // Text color for extra fields
    public var extraFieldFontSize: Double   // Font size for extra fields (0 = use main fontSize - 4)
    public var swapHeaderDeckAndCounts: Bool // Swap deck name and counter position in header

    public static let defaults = AnkiFloatingOverlayConfig(
        isEnabled: false,
        fontSize: 16.0,
        windowOpacity: 0.85,
        textOpacity: 1.0,
        windowWidth: 420.0,
        windowHeight: 300.0,
        showRatingButtons: true,
        showAudioButton: true,
        showSyncButton: true,
        showRevealButton: true,
        overlayFuriganaFontSize: 0,
        hideTitleBar: false,
        textColorHex: "#FFFFFF",
        backgroundColorHex: "#1E1E24",
        questionAnswerColorHex: "#808080",
        showHeader: true,
        showCounts: false,
        positionX: 0,
        positionY: 0,
        extraQuestionField: "",
        extraAnswerField: "",
        extraQuestionOnlyOnAnswer: false,
        extraFieldColorHex: "#00CED1",
        extraFieldFontSize: 0,
        swapHeaderDeckAndCounts: false
    )

    private static let userDefaultsKey = "AnkiFloatingOverlayConfig"

    public static func load() -> AnkiFloatingOverlayConfig {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey) else {
            return .defaults
        }
        do {
            return try JSONDecoder().decode(AnkiFloatingOverlayConfig.self, from: data)
        } catch {
            print("Failed to decode floating overlay config: \(error)")
            return .defaults
        }
    }

    public func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        } catch {
            print("Failed to save floating overlay config: \(error)")
        }
    }
}

// MARK: - Floating Overlay View Model

@MainActor
@Observable
public final class AnkiFloatingOverlayManager: NSObject {
    public static let shared = AnkiFloatingOverlayManager()

    public var config: AnkiFloatingOverlayConfig = .load() {
        didSet {
            config.save()
            updateWindowAppearance()
            overlayView?.config = config
            StatusItemManager.shared.refreshFloatingOverlayState()
        }
    }

    public var isShowing: Bool = false
    private var overlayWindow: NSPanel?
    private var overlayView: AnkiFloatingOverlayViewHost?
    private var isProgrammaticResize: Bool = false

    private override init() {
        super.init()
    }

    // MARK: - Public API

    public func toggle() {
        if isShowing {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        guard config.isEnabled else { return }
        // Don't show overlay if all Anki widgets are hidden
        guard hasVisibleAnkiWidget else { return }
        if overlayWindow == nil {
            createOverlayWindow()
        }
        // Refresh data from current Anki state before showing to avoid stale card data
        overlayView?.refreshContent()
        overlayWindow?.orderFront(nil)
        isShowing = true
        StatusItemManager.shared.refreshFloatingOverlayState()
    }

    public func hide() {
        overlayWindow?.orderOut(nil)
        isShowing = false
        StatusItemManager.shared.refreshFloatingOverlayState()
    }

    public func refreshOverlay() {
        guard config.isEnabled else {
            if isShowing { hide() }
            return
        }
        guard hasVisibleAnkiWidget else {
            if isShowing { hide() }
            return
        }
        guard let host = overlayView else {
            if isShowing {
                createOverlayWindow()
                overlayWindow?.orderFront(nil)
                isShowing = true
            }
            return
        }
        if !isShowing { return }
        host.refreshContent()
    }

    private var hasVisibleAnkiWidget: Bool {
        AppState.shared?.widgets.contains { $0.type == .anki && !$0.isHidden } ?? false
    }

    // MARK: - Window Setup

    private func createOverlayWindow() {
        let defaultX: CGFloat
        let defaultY: CGFloat
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            defaultX = screenFrame.midX - config.windowWidth / 2
            defaultY = screenFrame.minY + 60
        } else {
            defaultX = 400
            defaultY = 80
        }

        let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView]

        let contentRect = NSRect(
            x: config.positionX > 0 ? config.positionX : defaultX,
            y: config.positionY > 0 ? config.positionY : defaultY,
            width: config.windowWidth,
            height: max(150, config.windowHeight)
        )

        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.title = "Anki Overlay"
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.delegate = self

        if config.positionX <= 0 || config.positionY <= 0 {
            config.positionX = Double(contentRect.origin.x)
            config.positionY = Double(contentRect.origin.y)
            config.save()
        }

        let host = AnkiFloatingOverlayViewHost(config: config)
        self.overlayView = host

        host.connectAction = { AppState.shared?.ankiState.checkConnection() }
        host.revealAnswerAction = { AppState.shared?.ankiState.revealAnswer() }
        host.submitRatingAction = { ease in AppState.shared?.ankiState.submitRating(ease: ease) }
        host.toggleAudioAction = { AppState.shared?.ankiState.toggleAudio() }
        host.syncAction = { AppState.shared?.ankiState.syncDecks() }

        let hostingView = NSHostingView(rootView: FloatingOverlayContentView(host: host))
        hostingView.frame = contentRect
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        // Note: windowOpacity only affects the VisualEffectView background, NOT text.
        // panel.alphaValue is intentionally NOT set here — text opacity is handled
        // separately via SwiftUI modifiers using config.textOpacity.

        self.overlayWindow = panel
    }

    private func updateWindowAppearance() {
        guard let panel = overlayWindow else { return }

        isProgrammaticResize = true
        defer { isProgrammaticResize = false }

        // Update title bar visibility — hide ALL traffic light buttons, not just close
        panel.titleVisibility = config.hideTitleBar ? .hidden : .visible
        panel.standardWindowButton(.closeButton)?.isHidden = config.hideTitleBar
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = config.hideTitleBar
        panel.standardWindowButton(.zoomButton)?.isHidden = config.hideTitleBar

        // Update size — no max cap, user controls freely
        var frame = panel.frame
        let newWidth = max(200, config.windowWidth)
        let newHeight = max(150, config.windowHeight)
        frame.size.width = newWidth
        frame.size.height = newHeight
        panel.setFrame(frame, display: true, animate: true)
    }
}

// MARK: - NSPanel Delegate

extension AnkiFloatingOverlayManager: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        isShowing = false
        if let window = overlayWindow {
            config.positionX = window.frame.origin.x
            config.positionY = window.frame.origin.y
            config.save()
        }
        StatusItemManager.shared.refreshFloatingOverlayState()
    }

    public func windowDidResize(_ notification: Notification) {
        guard let window = overlayWindow else { return }
        guard !isProgrammaticResize else { return }
        var updated = self.config
        updated.windowWidth = window.frame.width
        updated.windowHeight = window.frame.height
        updated.positionX = window.frame.origin.x
        updated.positionY = window.frame.origin.y
        self.config = updated
    }

    public func windowDidMove(_ notification: Notification) {
        guard let window = overlayWindow else { return }
        config.positionX = window.frame.origin.x
        config.positionY = window.frame.origin.y
        config.save()
    }
}

// MARK: - Floating Overlay View Host (Observable State)

@MainActor
public final class AnkiFloatingOverlayViewHost: ObservableObject {
    @Published public var config: AnkiFloatingOverlayConfig
    @Published public var isConnected: Bool = false
    @Published public var hasCard: Bool = false
    @Published public var isShowingAnswer: Bool = false
    @Published public var questionText: String = ""
    @Published public var answerText: String = ""
    @Published public var isLoading: Bool = false
    @Published public var isSyncing: Bool = false
    @Published public var isMuted: Bool = false
    @Published public var isAudioPlaying: Bool = false
    @Published public var cardsReviewed: Int = 0
    @Published public var sessionDuration: String = ""
    @Published public var deckName: String = ""

    @Published public var hasDeckSelected: Bool = false
    @Published public var newCount: Int = 0
    @Published public var learnCount: Int = 0
    @Published public var reviewCount: Int = 0
    @Published public var cardTypeLabel: String = ""
    @Published public var cardTypeColorHex: String = "#FFFFFF"

    // Extra field values for overlay
    @Published public var extraQuestionText: String = ""
    @Published public var extraAnswerText: String = ""

    // Anki actions
    public var revealAnswerAction: (() -> Void)?
    public var submitRatingAction: ((Int) -> Void)?
    public var toggleAudioAction: (() -> Void)?
    public var syncAction: (() -> Void)?
    public var connectAction: (() -> Void)?

    // Settings read from Anki widget on each refresh
    public var furiganaFontSize: Double = 0
    public var furiganaVerticalOffset: Double = 0
    public var furiganaTextOffset: Double = 0
    public var combineFurigana: Bool = false
    public var boldColorHex: String = "#FFD60A"
    public var showAgain: Bool = true
    public var showHard: Bool = true
    public var showGood: Bool = true
    public var showEasy: Bool = true

    init(config: AnkiFloatingOverlayConfig) {
        self.config = config
    }

    public func refreshContent() {
        guard let state = AppState.shared?.ankiState else { return }
        updateFrom(state: state)
        if let widget = getAnkiWidget() {
            furiganaFontSize = widget.ankiFuriganaFontSize
            furiganaVerticalOffset = widget.ankiFuriganaVerticalOffset
            furiganaTextOffset = widget.ankiFuriganaSegmentOffset
            combineFurigana = widget.ankiCombineFurigana
            boldColorHex = widget.ankiBoldColorHex
            showAgain = widget.ankiShowAgain
            showHard = widget.ankiShowHard
            showGood = widget.ankiShowGood
            showEasy = widget.ankiShowEasy
        }
        // Populate extra fields from the widget's per-deck settings (not the global config)
        let widget = getAnkiWidget()
        let extraQField = widget?.ankiExtraQuestionField ?? config.extraQuestionField
        let extraAField = widget?.ankiExtraAnswerField ?? config.extraAnswerField
        if let card = state.currentCard {
            extraQuestionText = extractExtraFieldValue(from: extraQField, fields: card.fields)
            extraAnswerText = extractExtraFieldValue(from: extraAField, fields: card.fields)
        } else {
            extraQuestionText = ""
            extraAnswerText = ""
        }
    }

    /// Parse comma-separated field names, extract and join their values
    private func extractExtraFieldValue(from fieldString: String, fields: [String: String]) -> String {
        guard !fieldString.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        let fieldNames = fieldString.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var values: [String] = []
        for name in fieldNames {
            if let val = fields[name] {
                if !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Preserve HTML tags — will be parsed when rendering
                    values.append(val)
                }
            }
        }
        return values.joined(separator: " / ")
    }

    private func getAnkiWidget() -> TouchBarWidget? {
        guard let state = AppState.shared else { return nil }
        if let selectedID = state.selectedWidgetID,
           let widget = state.widgets.first(where: { $0.id == selectedID && $0.type == .anki }) {
            return widget
        }
        return state.widgets.first(where: { $0.type == .anki })
    }

    private func updateFrom(state: AnkiState) {
        isConnected = state.isConnected
        hasDeckSelected = !state.selectedDeck.isEmpty
        isLoading = state.isLoading
        isSyncing = state.isSyncing
        isShowingAnswer = state.isShowingAnswer
        isMuted = state.isMuted
        isAudioPlaying = state.isAudioPlaying
        cardsReviewed = state.cardsReviewed
        sessionDuration = state.sessionDuration
        newCount = state.newCount
        learnCount = state.learnCount
        reviewCount = state.reviewCount
        cardTypeLabel = state.currentCard?.cardTypeLabel ?? ""
        cardTypeColorHex = state.currentCard?.cardTypeColorHex ?? "#FFFFFF"

        if let card = state.currentCard {
            hasCard = true
            questionText = card.question
            answerText = card.answer
            deckName = card.deckName
        } else {
            hasCard = false
            questionText = ""
            answerText = ""
            deckName = ""
        }
    }


}

// MARK: - Helper: Strip HTML for plain text display

private func stripHTMLForOverlay(_ text: String) -> String {
    var result = text
    result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    result = result.replacingOccurrences(of: "&nbsp;", with: " ")
    result = result.replacingOccurrences(of: "&amp;", with: "&")
    result = result.replacingOccurrences(of: "&lt;", with: "<")
    result = result.replacingOccurrences(of: "&gt;", with: ">")
    result = result.replacingOccurrences(of: "&quot;", with: "\"")
    result = result.replacingOccurrences(of: "&#39;", with: "'")
    result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - SwiftUI Content View

public struct FloatingOverlayContentView: View {
    @ObservedObject var host: AnkiFloatingOverlayViewHost

    public var body: some View {
        VStack(spacing: 0) {
            if !host.isConnected {
                offlineView
            } else if !host.hasCard || host.isLoading {
                waitingView
            } else if !host.isShowingAnswer {
                questionPhaseView
            } else {
                answerPhaseView
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(host.config.windowOpacity)
        )
        .background(
            Color(hex: host.config.backgroundColorHex)
                .opacity(host.config.windowOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Offline View

    private var offlineView: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.fill.badge.person.crop")
                .font(.system(size: 32))
                .foregroundColor(.gray)

            Text("Anki Not Connected")
                .font(.system(size: host.config.fontSize, weight: .medium))
                .foregroundColor(textColor)

            Text("Make sure Anki is open and AnkiConnect is installed")
                .font(.system(size: host.config.fontSize - 4))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button(action: { host.connectAction?() }) {
                Text("Connect")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Waiting View

    private var waitingView: some View {
        VStack(spacing: 12) {
            if host.isLoading {
                ProgressView().scaleEffect(1.2)
                Text("Loading card...")
                    .font(.system(size: host.config.fontSize - 2))
                    .foregroundColor(.gray)
            } else if host.hasDeckSelected {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                Text("No cards to study")
                    .font(.system(size: host.config.fontSize, weight: .medium))
                    .foregroundColor(textColor)
            } else {
                Image(systemName: "tray.full")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                Text("Select a Deck to Start")
                    .font(.system(size: host.config.fontSize, weight: .medium))
                    .foregroundColor(textColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Question Phase

    private var questionPhaseView: some View {
        VStack(spacing: 8) {
            // Header: deck name + counts + sync (optional)
            if host.config.showHeader {
                if host.config.swapHeaderDeckAndCounts {
                    // Swapped: counter on left, deck name on right
                    HStack {
                        countsRow
                        Spacer()
                        Text(host.deckName)
                            .font(.system(size: host.config.fontSize - 4, weight: .semibold))
                            .foregroundColor(.purple)
                        if host.config.showSyncButton { syncButton }
                    }
                } else {
                    // Default: deck name on left, counter on right
                    HStack {
                        Text(host.deckName)
                            .font(.system(size: host.config.fontSize - 4, weight: .semibold))
                            .foregroundColor(.purple)
                        Spacer()
                        countsRow
                        if host.config.showSyncButton { syncButton }
                    }
                }
                Divider().background(Color.white.opacity(0.2))            } else if host.config.showCounts {
                // Counts only, no header or divider
                if host.config.swapHeaderDeckAndCounts {
                    HStack {
                        countsRow
                        Spacer()
                    }
                } else {
                    HStack {
                        Spacer()
                        countsRow
                    }
                }
            }

            ScrollView
                 {
                VStack(alignment: .leading, spacing: 4) {
                    cardContentText(host.questionText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Extra question field (hidden if toggle is set to only show in answer)
                    if !host.extraQuestionText.isEmpty && !host.config.extraQuestionOnlyOnAnswer {
                        extraFieldText(host.extraQuestionText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 4)

            // Reveal button
            if host.config.showRevealButton {
                Button(action: { host.revealAnswerAction?() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill").font(.system(size: 12))
                        Text("Show Answer")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Answer Phase

    private var answerPhaseView: some View {
        VStack(spacing: 8) {
            // Header: deck name + stats + sync (optional)
            if host.config.showHeader {
                HStack {
                    Text(host.deckName)
                        .font(.system(size: host.config.fontSize - 4, weight: .semibold))
                        .foregroundColor(.purple)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 9))
                        Text(host.sessionDuration).font(.system(size: 10, design: .monospaced))
                        Text("·").foregroundColor(.gray)
                        Text("\(host.cardsReviewed)").font(.system(size: 10, design: .monospaced)).fontWeight(.bold)
                        Text("cards").font(.system(size: 9)).foregroundColor(.gray)
                    }
                    .foregroundColor(.gray)
                }
                Divider().background(Color.white.opacity(0.2))
            } else if host.config.showCounts {
                // Counts only, no header or divider
                if host.config.swapHeaderDeckAndCounts {
                    HStack {
                        countsRow
                        Spacer()
                    }
                } else {
                    HStack {
                        Spacer()
                        countsRow
                    }
                }
            }

            // Question in answer phase — with furigana support when enabled
            questionAnswerPreviewText(host.questionText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .truncationMode(.tail)

            // Extra question field in answer phase
            if !host.extraQuestionText.isEmpty {
                extraFieldText(host.extraQuestionText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }

            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 2)

            // Answer
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    cardContentText(host.answerText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Extra answer field
                    if !host.extraAnswerText.isEmpty {
                        extraFieldText(host.extraAnswerText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                if host.config.showAudioButton { audioButton }
                if host.config.showSyncButton { syncButton }
                Spacer()
                if host.config.showRatingButtons { ratingButtons }
            }
        }
    }

    // MARK: - Sub-Views

    private var textColor: Color {
        Color(hex: host.config.textColorHex).opacity(host.config.textOpacity)
    }

    private var countsRow: some View {
        HStack(spacing: 6) {
            // Card type indicator: colored circle
            if !host.cardTypeLabel.isEmpty {
                Circle()
                    .fill(Color(hex: host.cardTypeColorHex))
                    .frame(width: 8, height: 8)
                Divider()
                    .frame(width: 1, height: 10)
                    .background(Color.white.opacity(0.3))
            }
            if host.newCount > 0 {
                Text("N:\(host.newCount)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.blue)
            }
            if host.learnCount > 0 {
                Text("L:\(host.learnCount)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.orange)
            }
            if host.reviewCount > 0 {
                Text("R:\(host.reviewCount)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.green)
            }
        }
    }

    @ViewBuilder
    private var syncButton: some View {
        Button(action: { host.syncAction?() }) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12))
                .foregroundColor(host.isSyncing ? .gray : .white)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(host.isSyncing)
    }

    @ViewBuilder
    private var audioButton: some View {
        Button(action: { host.toggleAudioAction?() }) {
            Image(systemName: host.isAudioPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color(hex: host.config.backgroundColorHex))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var ratingButtons: some View {
        HStack(spacing: 6) {
            if host.showAgain {
                Button(action: { host.submitRatingAction?(1) }) {
                    ratingButtonContent(title: "Again", color: .red)
                }.buttonStyle(.plain)
            }
            if host.showHard {
                Button(action: { host.submitRatingAction?(2) }) {
                    ratingButtonContent(title: "Hard", color: .orange)
                }.buttonStyle(.plain)
            }
            if host.showGood {
                Button(action: { host.submitRatingAction?(3) }) {
                    ratingButtonContent(title: "Good", color: .green)
                }.buttonStyle(.plain)
            }
            if host.showEasy {
                Button(action: { host.submitRatingAction?(4) }) {
                    ratingButtonContent(title: "Easy", color: .blue)
                }.buttonStyle(.plain)
            }
        }
    }

    private func ratingButtonContent(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(color)
            .cornerRadius(6)
    }

    // MARK: - Extra Field Label

    private func extraFieldLabel(_ label: String) -> some View {
        Text(label)
            .font(.system(size: host.config.fontSize - 6, weight: .semibold))
            .foregroundColor(Color(hex: host.config.extraFieldColorHex).opacity(0.7))
            .font(.system(size: extraFieldFontSize(), weight: .semibold))
            .padding(.top, 2)
    }

    // MARK: - Extra Field Font Size Helper

    private func extraFieldFontSize() -> CGFloat {
        if host.config.extraFieldFontSize > 0 {
            return CGFloat(host.config.extraFieldFontSize)
        }
        return CGFloat(host.config.fontSize - 4)
    }

    // MARK: - Extra Field Text (HTML-aware)

    /// Strip all HTML tags except bold/italic/underline, and decode HTML entities
    private func stripUnknownHTMLTags(_ html: String) -> String {
        var text = html
        // Strip all tags except <b>, <strong>, <i>, <em>, <u> and their closing variants
        text = text.replacingOccurrences(of: "<(?!/?(b|strong|i|em|u)\\b)[^>]+>", with: "", options: .regularExpression)
        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        // Collapse multiple whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func extraFieldText(_ text: String) -> some View {
        let cleanedText = stripUnknownHTMLTags(text)
        if host.combineFurigana {
            extraFieldFuriganaText(cleanedText)
        } else {
            parseHTMLTags(
                in: cleanedText,
                defaultColor: Color(hex: host.config.extraFieldColorHex).opacity(host.config.textOpacity),
                boldColor: Color(hex: host.config.extraFieldColorHex).opacity(host.config.textOpacity),
                fontSize: extraFieldFontSize()
            )
        }
    }

    @ViewBuilder
    private func extraFieldFuriganaText(_ text: String) -> some View {
        let segments = parseRichSegments(from: text)
        let effFuriSize: CGFloat = {
            if host.config.overlayFuriganaFontSize > 0 {
                return CGFloat(host.config.overlayFuriganaFontSize)
            }
            return CGFloat(host.furiganaFontSize)
        }()
        let renderedFuriSize: CGFloat = effFuriSize > 0
            ? max(3, effFuriSize)
            : max(4, extraFieldFontSize() * 0.25)
        let furiHeight = renderedFuriSize * 1.4 + CGFloat(host.furiganaVerticalOffset)
        let extraColor = Color(hex: host.config.extraFieldColorHex).opacity(host.config.textOpacity)

        WrappingHStack(spacing: 2, lineSpacing: 4) {
            ForEach(segments) { item in
                if let furi = item.furigana {
                    VStack(spacing: 0) {
                        Text(furi)
                            .font(.system(size: renderedFuriSize, weight: .medium))
                            .foregroundColor(extraColor.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .fixedSize()
                        Text(item.text)
                            .font(.system(size: extraFieldFontSize(), weight: item.isBold ? .bold : .regular))
                            .foregroundColor(extraColor)
                            .if(item.isItalic) { $0.italic() }
                            .if(item.isUnderline) { $0.underline() }
                    }
                } else {
                    Text(item.text)
                        .font(.system(size: extraFieldFontSize(), weight: item.isBold ? .bold : .regular))
                        .foregroundColor(extraColor)
                        .if(item.isItalic) { $0.italic() }
                        .if(item.isUnderline) { $0.underline() }
                        .padding(.top, furiHeight)
                }
            }
        }
    }

    // MARK: - Question Preview in Answer Phase

    @ViewBuilder
    private func questionAnswerPreviewText(_ text: String) -> some View {
        let previewFontSize = host.config.fontSize - 4
        let previewColor = Color(hex: host.config.questionAnswerColorHex).opacity(host.config.textOpacity)

        if host.combineFurigana {
            let effFuriSize: CGFloat = {
                if host.config.overlayFuriganaFontSize > 0 {
                    return CGFloat(host.config.overlayFuriganaFontSize)
                }
                return CGFloat(host.furiganaFontSize)
            }()
            let renderedFuriSize: CGFloat = effFuriSize > 0
                ? max(3, effFuriSize)
                : max(4, previewFontSize * 0.25)
            let segments = parseRichSegments(from: text)
            let furiHeight = renderedFuriSize * 1.4 + CGFloat(host.furiganaVerticalOffset)

            WrappingHStack(spacing: 2, lineSpacing: 4) {
                ForEach(segments) { item in
                    if let furi = item.furigana {
                        VStack(spacing: 0) {
                            Text(furi)
                                .font(.system(size: renderedFuriSize, weight: .medium))
                                .foregroundColor(previewColor.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .fixedSize()
                            Text(item.text)
                                .font(.system(size: previewFontSize, weight: item.isBold ? .bold : .regular))
                                .foregroundColor(previewColor)
                                .if(item.isItalic) { $0.italic() }
                                .if(item.isUnderline) { $0.underline() }
                        }
                    } else {
                        Text(item.text)
                            .font(.system(size: previewFontSize, weight: item.isBold ? .bold : .regular))
                            .foregroundColor(previewColor)
                            .if(item.isItalic) { $0.italic() }
                            .if(item.isUnderline) { $0.underline() }
                            .padding(.top, furiHeight)
                    }
                }
            }
        } else {
            Text(stripHTMLForOverlay(text))
                .font(.system(size: previewFontSize))
                .foregroundColor(previewColor)
        }
    }

    // MARK: - Card Content Text

    @ViewBuilder
    private func cardContentText(_ text: String) -> some View {
        let effectiveFuriSize: CGFloat = {
            if host.config.overlayFuriganaFontSize > 0 {
                return CGFloat(host.config.overlayFuriganaFontSize)
            }
            return CGFloat(host.furiganaFontSize)
        }()

        // Compute the actual rendered furigana size matching parseFuriganaRichText logic
        let renderedFuriSize: CGFloat = effectiveFuriSize > 0
            ? max(3, effectiveFuriSize)
            : max(4, host.config.fontSize * 0.25)

        if host.combineFurigana {
            wrappingFuriganaText(text, renderedFuriSize: renderedFuriSize)
                .offset(y: CGFloat(host.furiganaTextOffset))
        } else {
            // Parse HTML tags (bold/italic/underline) without furigana.
            // [furigana] brackets are shown literally as-is.
            parseHTMLTags(
                in: text,
                defaultColor: textColor,
                boldColor: Color(hex: host.boldColorHex).opacity(host.config.textOpacity),
                fontSize: host.config.fontSize
            )
        }
    }

    private func wrappingFuriganaText(_ text: String, renderedFuriSize: CGFloat) -> some View {
        let segments = parseRichSegments(from: text)
        let furiHeight = renderedFuriSize * 1.4 + CGFloat(host.furiganaVerticalOffset)
        return WrappingHStack(spacing: 2, lineSpacing: 4) {
            ForEach(segments) { item in
                if let furi = item.furigana {
                    VStack(spacing: 0) {
                        Text(furi)
                            .font(.system(size: renderedFuriSize, weight: .medium))
                            .foregroundColor(item.isBold
                                ? Color(hex: host.boldColorHex).opacity(0.65 * host.config.textOpacity)
                                : textColor.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .fixedSize()
                        Text(item.text)
                            .font(.system(size: host.config.fontSize, weight: item.isBold ? .bold : .regular))
                            .foregroundColor(item.isBold
                                ? Color(hex: host.boldColorHex).opacity(host.config.textOpacity)
                                : textColor)
                            .if(item.isItalic) { $0.italic() }
                            .if(item.isUnderline) { $0.underline() }
                    }
                } else {
                    Text(item.text)
                        .font(.system(size: host.config.fontSize, weight: item.isBold ? .bold : .regular))
                        .foregroundColor(item.isBold
                            ? Color(hex: host.boldColorHex).opacity(host.config.textOpacity)
                            : textColor)
                        .if(item.isItalic) { $0.italic() }
                        .if(item.isUnderline) { $0.underline() }
                        .padding(.top, furiHeight)
                }
            }
        }
    }
}

// MARK: - Visual Effect Background

public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
