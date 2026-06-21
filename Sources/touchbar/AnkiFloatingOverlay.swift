import SwiftUI
import AppKit
import WebKit

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
    // Overlay-specific field configuration (independent from Touch Bar widget)
    public var questionField: String       // Overlay question field(s), comma-separated; empty = use widget config
    public var answerField: String         // Overlay answer field(s), comma-separated; empty = use widget config
    public var audioField: String          // Overlay audio field; empty = use widget config
    public var extraQuestionField: String  // Additional question field for overlay (comma-separated)
    public var extraAnswerField: String    // Additional answer field for overlay (comma-separated)
    public var extraQuestionOnlyOnAnswer: Bool // Show extra question field only on answer phase
    public var extraFieldColorHex: String  // Text color for extra fields
    public var extraFieldFontSize: Double   // Font size for extra fields (0 = use main fontSize - 4)
    public var swapHeaderDeckAndCounts: Bool // Swap deck name and counter position in header
    public var boldColorHex: String         // Bold color for overlay; empty = use widget's bold color
    public var showButtonsInterval: Bool     // Show next review duration on rating buttons
    public var useCardTemplate: Bool         // Use custom card templates instead of default rendering

    enum CodingKeys: String, CodingKey {
        case isEnabled, fontSize, windowOpacity, textOpacity, windowWidth, windowHeight
        case showRatingButtons, showAudioButton, showSyncButton, showRevealButton
        case overlayFuriganaFontSize, hideTitleBar
        case textColorHex, backgroundColorHex, questionAnswerColorHex
        case showHeader, showCounts, positionX, positionY
        case questionField, answerField, audioField
        case extraQuestionField, extraAnswerField, extraQuestionOnlyOnAnswer
        case extraFieldColorHex, extraFieldFontSize
        case swapHeaderDeckAndCounts, boldColorHex
        case showButtonsInterval
        case useCardTemplate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        self.fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 16
        self.windowOpacity = try container.decodeIfPresent(Double.self, forKey: .windowOpacity) ?? 0.85
        self.textOpacity = try container.decodeIfPresent(Double.self, forKey: .textOpacity) ?? 1.0
        self.windowWidth = try container.decodeIfPresent(Double.self, forKey: .windowWidth) ?? 420
        self.windowHeight = try container.decodeIfPresent(Double.self, forKey: .windowHeight) ?? 300
        self.showRatingButtons = try container.decodeIfPresent(Bool.self, forKey: .showRatingButtons) ?? true
        self.showAudioButton = try container.decodeIfPresent(Bool.self, forKey: .showAudioButton) ?? true
        self.showSyncButton = try container.decodeIfPresent(Bool.self, forKey: .showSyncButton) ?? true
        self.showRevealButton = try container.decodeIfPresent(Bool.self, forKey: .showRevealButton) ?? true
        self.overlayFuriganaFontSize = try container.decodeIfPresent(Double.self, forKey: .overlayFuriganaFontSize) ?? 0
        self.hideTitleBar = try container.decodeIfPresent(Bool.self, forKey: .hideTitleBar) ?? false
        self.textColorHex = try container.decodeIfPresent(String.self, forKey: .textColorHex) ?? "#FFFFFF"
        self.backgroundColorHex = try container.decodeIfPresent(String.self, forKey: .backgroundColorHex) ?? "#1E1E24"
        self.questionAnswerColorHex = try container.decodeIfPresent(String.self, forKey: .questionAnswerColorHex) ?? "#808080"
        self.showHeader = try container.decodeIfPresent(Bool.self, forKey: .showHeader) ?? true
        self.showCounts = try container.decodeIfPresent(Bool.self, forKey: .showCounts) ?? false
        self.positionX = try container.decodeIfPresent(Double.self, forKey: .positionX) ?? 0
        self.positionY = try container.decodeIfPresent(Double.self, forKey: .positionY) ?? 0
        self.questionField = try container.decodeIfPresent(String.self, forKey: .questionField) ?? ""
        self.answerField = try container.decodeIfPresent(String.self, forKey: .answerField) ?? ""
        self.audioField = try container.decodeIfPresent(String.self, forKey: .audioField) ?? ""
        self.extraQuestionField = try container.decodeIfPresent(String.self, forKey: .extraQuestionField) ?? ""
        self.extraAnswerField = try container.decodeIfPresent(String.self, forKey: .extraAnswerField) ?? ""
        self.extraQuestionOnlyOnAnswer = try container.decodeIfPresent(Bool.self, forKey: .extraQuestionOnlyOnAnswer) ?? false
        self.extraFieldColorHex = try container.decodeIfPresent(String.self, forKey: .extraFieldColorHex) ?? "#00CED1"
        self.extraFieldFontSize = try container.decodeIfPresent(Double.self, forKey: .extraFieldFontSize) ?? 0
        self.swapHeaderDeckAndCounts = try container.decodeIfPresent(Bool.self, forKey: .swapHeaderDeckAndCounts) ?? false
        self.boldColorHex = try container.decodeIfPresent(String.self, forKey: .boldColorHex) ?? ""
        self.showButtonsInterval = try container.decodeIfPresent(Bool.self, forKey: .showButtonsInterval) ?? true
        self.useCardTemplate = try container.decodeIfPresent(Bool.self, forKey: .useCardTemplate) ?? false
    }

    public init(isEnabled: Bool = false, fontSize: Double = 16, windowOpacity: Double = 0.85, textOpacity: Double = 1.0, windowWidth: Double = 420, windowHeight: Double = 300, showRatingButtons: Bool = true, showAudioButton: Bool = true, showSyncButton: Bool = true, showRevealButton: Bool = true, overlayFuriganaFontSize: Double = 0, hideTitleBar: Bool = false, textColorHex: String = "#FFFFFF", backgroundColorHex: String = "#1E1E24", questionAnswerColorHex: String = "#808080", showHeader: Bool = true, showCounts: Bool = false, positionX: Double = 0, positionY: Double = 0, questionField: String = "", answerField: String = "", audioField: String = "", extraQuestionField: String = "", extraAnswerField: String = "", extraQuestionOnlyOnAnswer: Bool = false, extraFieldColorHex: String = "#00CED1", extraFieldFontSize: Double = 0, swapHeaderDeckAndCounts: Bool = false, boldColorHex: String = "", showButtonsInterval: Bool = true, useCardTemplate: Bool = false) {
        self.isEnabled = isEnabled
        self.fontSize = fontSize
        self.windowOpacity = windowOpacity
        self.textOpacity = textOpacity
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.showRatingButtons = showRatingButtons
        self.showAudioButton = showAudioButton
        self.showSyncButton = showSyncButton
        self.showRevealButton = showRevealButton
        self.overlayFuriganaFontSize = overlayFuriganaFontSize
        self.hideTitleBar = hideTitleBar
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
        self.questionAnswerColorHex = questionAnswerColorHex
        self.showHeader = showHeader
        self.showCounts = showCounts
        self.positionX = positionX
        self.positionY = positionY
        self.questionField = questionField
        self.answerField = answerField
        self.audioField = audioField
        self.extraQuestionField = extraQuestionField
        self.extraAnswerField = extraAnswerField
        self.extraQuestionOnlyOnAnswer = extraQuestionOnlyOnAnswer
        self.extraFieldColorHex = extraFieldColorHex
        self.extraFieldFontSize = extraFieldFontSize
        self.swapHeaderDeckAndCounts = swapHeaderDeckAndCounts
        self.boldColorHex = boldColorHex
        self.showButtonsInterval = showButtonsInterval
        self.useCardTemplate = useCardTemplate
    }

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
        questionField: "",
        answerField: "",
        audioField: "",
        extraQuestionField: "",
        extraAnswerField: "",
        extraQuestionOnlyOnAnswer: false,
        extraFieldColorHex: "#00CED1",
        extraFieldFontSize: 0,
        swapHeaderDeckAndCounts: false,
        boldColorHex: "",
        showButtonsInterval: true,
        useCardTemplate: false
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
        if #available(macOS 14.0, *) {
            hostingView.sizingOptions = []
        }
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

    // Button interval durations
    @Published public var buttonIntervals: [Int: Int] = [:]
    @Published public var buttonLabels: [Int: String] = [:]

    // Card template rendering
    @Published public var renderedQuestionHTML: String = ""
    @Published public var renderedAnswerHTML: String = ""
    @Published public var hasCardTemplate: Bool = false

    // Track current card ID to detect new cards for the persistent WebView
    public var currentCardId: Int = 0

    // Anki actions
    public var revealAnswerAction: (() -> Void)?
    public var submitRatingAction: ((Int) -> Void)?
    public var toggleAudioAction: (() -> Void)?
    public var syncAction: (() -> Void)?
    public var connectAction: (() -> Void)?
    public var importTemplatesAction: (() async -> Void)?

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
    public var showButtonsInterval: Bool = true
    public var buttonCount: Int = 4

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
            boldColorHex = config.boldColorHex.isEmpty ? widget.ankiBoldColorHex : config.boldColorHex
            showAgain = widget.ankiShowAgain
            showHard = widget.ankiShowHard
            showGood = widget.ankiShowGood
            showEasy = widget.ankiShowEasy
            showButtonsInterval = config.showButtonsInterval
        }

        if let card = state.currentCard {
            // Compute question/answer from overlay-specific field config if set,
            // otherwise use widget config. If the configured fields are empty (not just
            // absent from the card), show empty string instead of Anki's fallback rendering.
            let qField = config.questionField.isEmpty
                ? (getAnkiWidget()?.ankiQuestionField ?? "")
                : config.questionField
            let aField = config.answerField.isEmpty
                ? (getAnkiWidget()?.ankiAnswerField ?? "")
                : config.answerField
            questionText = extractOverlayFieldValue(from: qField, fields: card.fields) ?? ""
            answerText = extractOverlayFieldValue(from: aField, fields: card.fields) ?? ""

            // Extra fields: overlay config takes precedence, fall back to widget config
            let extraQField = config.extraQuestionField.isEmpty
                ? (getAnkiWidget()?.ankiExtraQuestionField ?? "")
                : config.extraQuestionField
            let extraAField = config.extraAnswerField.isEmpty
                ? (getAnkiWidget()?.ankiExtraAnswerField ?? "")
                : config.extraAnswerField
            extraQuestionText = extractExtraFieldValue(from: extraQField, fields: card.fields)
            extraAnswerText = extractExtraFieldValue(from: extraAField, fields: card.fields)

            currentCardId = card.cardId

            // Render card templates if enabled and available
            if config.useCardTemplate {
                renderCardTemplates(card: card)
            } else {
                renderedQuestionHTML = ""
                renderedAnswerHTML = ""
                hasCardTemplate = false
            }
        } else {
            currentCardId = 0
            questionText = ""
            answerText = ""
            extraQuestionText = ""
            extraAnswerText = ""
            renderedQuestionHTML = ""
            renderedAnswerHTML = ""
            hasCardTemplate = false
        }
    }

    private func renderCardTemplates(card: AnkiCard) {
        guard let widget = getAnkiWidget() else {
            hasCardTemplate = false
            renderedQuestionHTML = ""
            renderedAnswerHTML = ""
            return
        }
        // Try exact deck name match first, then prefix match (parent deck)
        let settings: AnkiDeckSettings?
        if let exact = widget.ankiDeckSettings[card.deckName] {
            settings = exact
        } else {
            let matchingKey = widget.ankiDeckSettings.keys
                .filter { card.deckName == $0 || card.deckName.hasPrefix($0 + "::") }
                .sorted { $0.count > $1.count }
                .first
            settings = matchingKey.flatMap { widget.ankiDeckSettings[$0] }
        }
        guard let settings = settings,
              !settings.frontTemplate.isEmpty || !settings.backTemplate.isEmpty else {
            hasCardTemplate = false
            renderedQuestionHTML = ""
            renderedAnswerHTML = ""
            return
        }
        hasCardTemplate = true
        let renderedFront = processTemplate(settings.frontTemplate, fields: card.fields, css: settings.templateCss, deckName: card.deckName, frontSideRendered: nil)
        renderedQuestionHTML = wrapTemplateInHTML(body: renderedFront, css: settings.templateCss)
        let renderedBack = processTemplate(settings.backTemplate, fields: card.fields, css: settings.templateCss, deckName: card.deckName, frontSideRendered: renderedFront)
        renderedAnswerHTML = wrapTemplateInHTML(body: renderedBack, css: settings.templateCss)
    }

    private func wrapTemplateInHTML(body: String, css: String) -> String {
        """
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        \(css)
        body {
            font-family: -apple-system, 'Helvetica Neue', sans-serif;
            font-size: \(config.fontSize)px;
            color: #\(config.textColorHex.hasPrefix("#") ? String(config.textColorHex.dropFirst()) : config.textColorHex);
            background: transparent;
            padding: 0;
            margin: 0;
            word-wrap: break-word;
            overflow-wrap: break-word;
            line-height: 1.6;
            -webkit-user-select: none;
            user-select: none;
        }
        img { max-width: 100%; height: auto; }
        a { color: #007AFF; }
        ruby { ruby-align: center; -webkit-ruby-align: center; }
        </style>
        </head>
        <body class="card">\(body)</body>
        </html>
        """

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

    /// Parse comma-separated field names, extract and join their values with HTML stripped,
    /// matching how AnkiConnectClient renders question/answer for the widget.
    private func extractOverlayFieldValue(from fieldString: String, fields: [String: String]) -> String? {
        let trimmed = fieldString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let fieldNames = trimmed.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var values: [String] = []
        for name in fieldNames {
            if let val = fields[name] {
                let stripped = stripHTMLForOverlay(val)
                if !stripped.isEmpty {
                    values.append(stripped)
                }
            }
        }
        guard !values.isEmpty else { return nil }
        return values.joined(separator: " / ")
    }

    /// Process an Anki card template by replacing field references with actual values.
    /// Supported: {{FieldName}}, {{text:FieldName}}, {{FrontSide}}, {{#FieldName}}...{{/FieldName}}, {{^FieldName}}...{{/FieldName}},
    /// {{Deck}}, {{Subdeck}}, {{Tags}}, {{Card}}, {{Type}}
    private func processTemplate(_ template: String, fields: [String: String], css: String, deckName: String, frontSideRendered: String?) -> String {
        // 1. Handle conditionals: {{#Field}}...{{/Field}} and {{^Field}}...{{/Field}}
        var result = template
        // Match {{#FieldName}}...{{/FieldName}} (including nested, non-greedy)
        if let regex = try? NSRegularExpression(pattern: #"\{\{#([^}]+)\}\}(.*?)\{\{\/\1\}\}"#, options: [.dotMatchesLineSeparators]) {
            while true {
                let range = NSRange(result.startIndex..., in: result)
                guard let match = regex.firstMatch(in: result, options: [], range: range) else { break }
                let fieldName = String(result[Range(match.range(at: 1), in: result)!])
                let content = String(result[Range(match.range(at: 2), in: result)!])
                let fieldValue = fields[fieldName]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let replacement = fieldValue.isEmpty ? "" : content
                result.replaceSubrange(Range(match.range, in: result)!, with: replacement)
            }
        }
        // Match {{^FieldName}}...{{/FieldName}} (inverse conditional)
        if let regex = try? NSRegularExpression(pattern: #"\{\{\^([^}]+)\}\}(.*?)\{\{\/\1\}\}"#, options: [.dotMatchesLineSeparators]) {
            while true {
                let range = NSRange(result.startIndex..., in: result)
                guard let match = regex.firstMatch(in: result, options: [], range: range) else { break }
                let fieldName = String(result[Range(match.range(at: 1), in: result)!])
                let content = String(result[Range(match.range(at: 2), in: result)!])
                let fieldValue = fields[fieldName]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let replacement = fieldValue.isEmpty ? content : ""
                result.replaceSubrange(Range(match.range, in: result)!, with: replacement)
            }
        }

        // 2. Handle {{FrontSide}}
        if let frontSide = frontSideRendered {
            result = result.replacingOccurrences(of: "{{FrontSide}}", with: frontSide)
        } else {
            result = result.replacingOccurrences(of: "{{FrontSide}}", with: "")
        }

        // 3. Handle special fields
        result = result.replacingOccurrences(of: "{{Deck}}", with: deckName)
        // Extract subdeck (last part after ::)
        let deckParts = deckName.components(separatedBy: "::")
        let subdeck = deckParts.last ?? deckName
        result = result.replacingOccurrences(of: "{{Subdeck}}", with: subdeck)

        // 4. Handle {{text:FieldName}} — strip HTML from field value
        if let textRegex = try? NSRegularExpression(pattern: #"\{\{text:([^}]+)\}\}"#) {
            while true {
                let range = NSRange(result.startIndex..., in: result)
                guard let match = textRegex.firstMatch(in: result, options: [], range: range) else { break }
                let fieldName = String(result[Range(match.range(at: 1), in: result)!])
                let stripped = stripHTMLForOverlay(fields[fieldName] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                result.replaceSubrange(Range(match.range, in: result)!, with: stripped)
            }
        }

        // 4b. Handle {{furigana:FieldName}} — convert Kanji[reading] notation to ruby HTML
        if let furiganaRegex = try? NSRegularExpression(pattern: #"\{\{furigana:([^}]+)\}\}"#) {
            while true {
                let range = NSRange(result.startIndex..., in: result)
                guard let match = furiganaRegex.firstMatch(in: result, options: [], range: range) else { break }
                let fieldName = String(result[Range(match.range(at: 1), in: result)!])
                let value = furiganaToRuby(fields[fieldName] ?? "")
                result.replaceSubrange(Range(match.range, in: result)!, with: value)
            }
        }

        // 4c. Handle other {{filterName:FieldName}} — strip unknown filter prefix, use raw value
        if let filterRegex = try? NSRegularExpression(pattern: #"\{\{[a-zA-Z]+:([^}]+)\}\}"#) {
            while true {
                let range = NSRange(result.startIndex..., in: result)
                guard let match = filterRegex.firstMatch(in: result, options: [], range: range) else { break }
                let fieldName = String(result[Range(match.range(at: 1), in: result)!])
                let value = fields[fieldName] ?? ""
                result.replaceSubrange(Range(match.range, in: result)!, with: value)
            }
        }

        // 5. Handle standard {{FieldName}} — insert raw field value (HTML preserved)
        if let fieldRegex = try? NSRegularExpression(pattern: #"\{\{([^}#^\/:]+)\}\}"#) {
            while true {
                let range = NSRange(result.startIndex..., in: result)
                guard let match = fieldRegex.firstMatch(in: result, options: [], range: range) else { break }
                let fieldName = String(result[Range(match.range(at: 1), in: result)!]).trimmingCharacters(in: .whitespaces)
                let value = fields[fieldName] ?? ""
                result.replaceSubrange(Range(match.range, in: result)!, with: value)
            }
        }

        return result
    }

    /// Convert Anki furigana notation `Kanji[reading]` to HTML ruby annotations.
    /// Uses Unicode Han property to match only CJK characters as kanji base,
    /// and ruby-align:center to prevent distributed ruby in WKWebView.
    private func furiganaToRuby(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(\p{Han}+)\[([^\[\]<>]+)\]"#) else { return text }
        var result = text
        while true {
            let range = NSRange(result.startIndex..., in: result)
            guard let match = regex.firstMatch(in: result, options: [], range: range) else { break }
            let kanji = result[Range(match.range(at: 1), in: result)!]
            let reading = result[Range(match.range(at: 2), in: result)!]
            let ruby = "<ruby style=\"ruby-align:center;-webkit-ruby-align:center\">\(kanji)<rt>\(reading)</rt></ruby>"
            result.replaceSubrange(Range(match.range, in: result)!, with: ruby)
        }
        return result
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

        buttonIntervals = state.buttonIntervals
        buttonLabels = state.buttonLabels
        buttonCount = state.currentCard?.buttonCount ?? 4

        if let card = state.currentCard {
            hasCard = true
            deckName = card.deckName
            // questionText and answerText are set in refreshContent() to support
            // overlay-specific field configuration
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
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if !host.isConnected {
                    offlineView
                } else if !host.hasCard || host.isLoading {
                    waitingView
                } else if host.hasCardTemplate {
                    // Single persistent WebView for both question and answer phases
                    templatePhaseView(proxy: proxy)
                } else if !host.isShowingAnswer {
                    questionPhaseView
                } else {
                    answerPhaseView
                }
            }
            .frame(width: proxy.size.width - 24, alignment: .top)
            .padding(12)
        }
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

    /// Single persistent template WebView that handles both question and answer phases.
    /// The WebView keeps the same instance across transitions, preserving JavaScript state
    /// by saving checkbox/input states before loading the answer HTML and restoring them after.
    @ViewBuilder
    private func templatePhaseView(proxy: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            // Header
            if host.config.showHeader {
                headerContent
                Divider().background(Color.white.opacity(0.2))
            }

            // Card content (persistent WebView — same instance across phases)
            GeometryReader { geo in
                CardTemplateWebView(
                    html: host.isShowingAnswer ? host.renderedAnswerHTML : host.renderedQuestionHTML,
                    isShowingAnswer: host.isShowingAnswer,
                    cardId: host.currentCardId,
                    maxSize: geo.size,
                    onPycmd: { cmd in
                        if cmd == "answer" || cmd == "reveal" {
                            host.revealAnswerAction?()
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 4)

            // Phase-specific buttons
            if host.isShowingAnswer {
                HStack(spacing: 8) {
                    if host.config.showAudioButton { audioButton }
                    if host.config.showSyncButton { syncButton }
                    Spacer()
                    if host.config.showRatingButtons { ratingButtons }
                }
            } else {
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
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var headerContent: some View {
        Group {
            if host.config.swapHeaderDeckAndCounts {
                HStack {
                    countsRow
                    Spacer()
                    Text(host.deckName)
                        .font(.system(size: host.config.fontSize - 4, weight: .semibold))
                        .foregroundColor(.purple)
                    if host.config.showSyncButton { syncButton }
                }
            } else {
                HStack {
                    Text(host.deckName)
                        .font(.system(size: host.config.fontSize - 4, weight: .semibold))
                        .foregroundColor(.purple)
                    Spacer()
                    countsRow
                    if host.config.showSyncButton { syncButton }
                }
            }
        }
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
                headerContent
                Divider().background(Color.white.opacity(0.2))
            } else if host.config.showCounts {
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

            ScrollView([.vertical]) {
                VStack(alignment: .leading, spacing: 4) {
                    if questionTextIsEmpty {
                        placeholderText("question")
                    } else {
                        cardContentText(host.questionText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !host.extraQuestionText.isEmpty && !host.config.extraQuestionOnlyOnAnswer {
                        extraFieldText(host.extraQuestionText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
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
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Answer Phase

    private var questionTextIsEmpty: Bool {
        host.questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var answerTextIsEmpty: Bool {
        host.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func placeholderText(_ fieldName: String) -> some View {
        Text("Please fill in the \(fieldName) field")
            .font(.system(size: host.config.fontSize, weight: .medium))
            .foregroundColor(textColor.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var answerPhaseView: some View {
        VStack(spacing: 8) {
            // Header: deck name + stats + sync (optional)
            if host.config.showHeader {
                HStack {
                    Text(host.deckName)
                        .font(.system(size: host.config.fontSize - 4, weight: .semibold))
                        .foregroundColor(.purple)
                    Spacer()
                    intervalHeaderText
                        .foregroundColor(.purple)
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
            ScrollView([.vertical]) {
                VStack(alignment: .leading, spacing: 4) {
                    if answerTextIsEmpty {
                        placeholderText("answer")
                    } else {
                        cardContentText(host.answerText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if !host.extraAnswerText.isEmpty {
                        extraFieldText(host.extraAnswerText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
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
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Sub-Views

    private var textColor: Color {
        Color(hex: host.config.textColorHex).opacity(host.config.textOpacity)
    }

    private var intervalHeaderText: some View {
        let s = intervalSummary
        if s.isEmpty {
            return AnyView(EmptyView())
        }
        return AnyView(
            HStack(spacing: 4) {
                Text(s)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                Divider()
                    .frame(width: 1, height: 10)
                    .background(Color.white.opacity(0.3))
            }
        )
    }

    private var intervalSummary: String {
        guard !host.showButtonsInterval else { return "" }
        let labels = host.buttonLabels
        let bc = host.buttonCount
        var parts: [String] = []
        let buttonConfig: [(visible: Bool, title: String, prefix: String)] = [
            (host.showAgain, "Again", "A"),
            (host.showHard, "Hard", "H"),
            (host.showGood, "Good", "G"),
            (host.showEasy, "Easy", "E"),
        ]
        for (visible, title, prefix) in buttonConfig {
            guard visible else { continue }
            let pos = intervalPosition(for: title, buttonCount: bc)
            guard pos > 0, let label = labels[pos], !label.isEmpty else { continue }
            parts.append("\(prefix):\(label)")
        }
        return parts.isEmpty ? "" : parts.joined(separator: " ")
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
            let summary = intervalSummary
            if !summary.isEmpty {
                Divider()
                    .frame(width: 1, height: 10)
                    .background(Color.white.opacity(0.3))
                Text(summary)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.purple)
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
                    ratingButtonContent(title: "Again", color: .red, rating: 1)
                }.buttonStyle(.plain)
            }
            if host.showHard {
                Button(action: { host.submitRatingAction?(2) }) {
                    ratingButtonContent(title: "Hard", color: .orange, rating: 2)
                }.buttonStyle(.plain)
            }
            if host.showGood {
                Button(action: { host.submitRatingAction?(3) }) {
                    ratingButtonContent(title: "Good", color: .green, rating: 3)
                }.buttonStyle(.plain)
            }
            if host.showEasy {
                Button(action: { host.submitRatingAction?(4) }) {
                    ratingButtonContent(title: "Easy", color: .blue, rating: 4)
                }.buttonStyle(.plain)
            }
        }
    }

    /// Map button name + buttonCount to the correct position for label/interval lookup.
    private func intervalPosition(for title: String, buttonCount: Int) -> Int {
        switch title {
        case "Again": return 1
        case "Hard": return 2
        case "Good": return buttonCount == 2 ? 2 : 3
        case "Easy":
            if buttonCount >= 4 { return 4 }
            if buttonCount >= 3 { return 3 }
            return 2
        default: return -1
        }
    }

    private func ratingButtonContent(title: String, color: Color, rating: Int) -> some View {
        let intervalSuffix: String = {
            guard host.showButtonsInterval else { return "" }
            let pos = intervalPosition(for: title, buttonCount: host.buttonCount)
            guard pos > 0, let label = host.buttonLabels[pos], !label.isEmpty else { return "" }
            return " (\(label))"
        }()
        return Text(title + intervalSuffix)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(color)
            .cornerRadius(6)
    }

    /// Split non-furigana text into individual characters for CJK wrapping.
    /// Text with spaces (Latin) is kept whole so `Text` word-wraps natively.
    private func splitForWrapping(_ text: String) -> [String] {
        guard !text.contains(" ") else { return [text] }
        return text.map { String($0) }
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

    private func insertBreakOpportunities(_ text: String) -> String {
        guard !text.contains(" ") else { return text }
        return text.map { String($0) }.joined(separator: "\u{200B}")
    }

    @ViewBuilder
    private func extraFieldText(_ text: String) -> some View {
        let cleanedText = stripUnknownHTMLTags(text)
        if host.combineFurigana {
            extraFieldFuriganaText(cleanedText)
        } else {
            parseHTMLTags(
                in: insertBreakOpportunities(cleanedText),
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
                } else if item.text.contains(" ") {
                    Text(item.text)
                        .font(.system(size: extraFieldFontSize(), weight: item.isBold ? .bold : .regular))
                        .foregroundColor(extraColor)
                        .if(item.isItalic) { $0.italic() }
                        .if(item.isUnderline) { $0.underline() }
                        .padding(.top, furiHeight)
                } else {
                    ForEach(Array(splitForWrapping(item.text).enumerated()), id: \.offset) { _, char in
                        Text(char)
                            .font(.system(size: extraFieldFontSize(), weight: item.isBold ? .bold : .regular))
                            .foregroundColor(extraColor)
                            .if(item.isItalic) { $0.italic() }
                            .if(item.isUnderline) { $0.underline() }
                            .padding(.top, furiHeight)
                    }
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
                    } else if item.text.contains(" ") {
                        Text(item.text)
                            .font(.system(size: previewFontSize, weight: item.isBold ? .bold : .regular))
                            .foregroundColor(previewColor)
                            .if(item.isItalic) { $0.italic() }
                            .if(item.isUnderline) { $0.underline() }
                            .padding(.top, furiHeight)
                    } else {
                        ForEach(Array(splitForWrapping(item.text).enumerated()), id: \.offset) { _, char in
                            Text(char)
                                .font(.system(size: previewFontSize, weight: item.isBold ? .bold : .regular))
                                .foregroundColor(previewColor)
                                .if(item.isItalic) { $0.italic() }
                                .if(item.isUnderline) { $0.underline() }
                                .padding(.top, furiHeight)
                        }
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
            parseHTMLTags(
                in: insertBreakOpportunities(text),
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
                } else if item.text.contains(" ") {
                    Text(item.text)
                        .font(.system(size: host.config.fontSize, weight: item.isBold ? .bold : .regular))
                        .foregroundColor(item.isBold
                            ? Color(hex: host.boldColorHex).opacity(host.config.textOpacity)
                            : textColor)
                        .if(item.isItalic) { $0.italic() }
                        .if(item.isUnderline) { $0.underline() }
                        .padding(.top, furiHeight)
                } else {
                    ForEach(Array(splitForWrapping(item.text).enumerated()), id: \.offset) { _, char in
                        Text(char)
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
}

// MARK: - Card Template WebView

/// A persistent WebView that:
/// - Keeps the same WKWebView across question→answer transitions
/// - Detects new cards (via cardId) and does a full load
/// - On answer reveal: saves checkbox/input state via JS before loading answer HTML,
///   then restores state after the answer page finishes loading
private let saveStateJS = """
(function() {
    var items = [];
    document.querySelectorAll('input, select, textarea').forEach(function(el) {
        if (el.id || el.name) {
            items.push({
                id: el.id || '',
                name: el.name || '',
                type: el.type || '',
                tag: el.tagName,
                checked: el.checked,
                value: el.value
            });
        }
    });
    return JSON.stringify(items);
})();
"""

private let restoreStateJS = """
(function(json) {
    try {
        var states = JSON.parse(json);
        states.forEach(function(s) {
            var el = s.id ? document.getElementById(s.id) : null;
            if (!el && s.name) el = document.querySelector('[name="' + s.name.replace(/"/g, '\\\\"') + '"]');
            if (!el) return;
            if (s.type === 'checkbox' || s.type === 'radio') {
                el.checked = s.checked;
            } else {
                el.value = s.value;
            }
        });
    } catch(e) {}
})(STATES_PLACEHOLDER);
"""

public struct CardTemplateWebView: NSViewRepresentable {
    let html: String
    var isShowingAnswer: Bool = false
    var cardId: Int = -1
    var maxSize: CGSize
    var onPycmd: ((String) -> Void)?

    /// Find Anki's collection.media directory for resolving relative image paths.
    private static var ankiMediaURL: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let ankiDir = home.appendingPathComponent("Library/Application Support/Anki2")
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: ankiDir.path) else { return nil }
        for item in contents {
            let mediaPath = ankiDir.appendingPathComponent("\(item)/collection.media")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: mediaPath.path, isDirectory: &isDir), isDir.boolValue {
                return mediaPath
            }
        }
        return nil
    }

    /// WKWebView subclass that allows window dragging from its content area.
    private final class DragWebView: WKWebView, WKScriptMessageHandler {
        override var mouseDownCanMoveWindow: Bool { true }
        var onPycmd: ((String) -> Void)?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "pycmd":
                if let cmd = message.body as? String {
                    print("[WebView pycmd] \(cmd)")
                    onPycmd?(cmd)
                }
            default:
                print("[WebView \(message.name)] \(message.body)")
            }
        }
    }

    public final class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedCardId: Int = -1
        var answerRevealed: Bool = false
        var pendingStateRestore: String?
        weak var webView: WKWebView?

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let json = pendingStateRestore {
                let js = restoreStateJS.replacingOccurrences(of: "STATES_PLACEHOLDER", with: json)
                webView.evaluateJavaScript(js, completionHandler: nil)
                pendingStateRestore = nil
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let uc = config.userContentController
        uc.addUserScript(Self.jQueryScript)
        uc.addUserScript(Self.consoleCaptureScript)
        uc.addUserScript(Self.viewportScript)
        let webView = DragWebView(frame: .zero, configuration: config)
        uc.add(webView, name: "log")
        uc.add(webView, name: "warn")
        uc.add(webView, name: "error")
        uc.add(webView, name: "pycmd")
        webView.onPycmd = onPycmd
        webView.setValue(false, forKey: "drawsBackground")
        webView.isHidden = html.isEmpty
        if #available(macOS 14.0, *) {
            webView.isInspectable = true
        }
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        guard !html.isEmpty else {
            webView.isHidden = true
            return
        }
        webView.isHidden = false
        (webView as? DragWebView)?.onPycmd = onPycmd

        let co = context.coordinator
        if co.lastLoadedCardId != cardId {
            // New card: load question HTML
            webView.loadHTMLString(html, baseURL: Self.ankiMediaURL)
            co.lastLoadedCardId = cardId
            co.answerRevealed = false
            co.pendingStateRestore = nil
            return
        }

        if isShowingAnswer && !co.answerRevealed {
            // Reveal answer: save input states, then load answer HTML
            co.answerRevealed = true
            let currentHTML = html
            webView.evaluateJavaScript(saveStateJS) { result, _ in
                if let json = result as? String {
                    co.pendingStateRestore = json
                }
                webView.loadHTMLString(currentHTML, baseURL: Self.ankiMediaURL)
            }
        } else if !isShowingAnswer && co.answerRevealed {
            // Back to question: save input states, then load question HTML
            co.answerRevealed = false
            let currentHTML = html
            webView.evaluateJavaScript(saveStateJS) { result, _ in
                if let json = result as? String {
                    co.pendingStateRestore = json
                }
                webView.loadHTMLString(currentHTML, baseURL: Self.ankiMediaURL)
            }
        } else if co.pendingStateRestore != nil && !webView.isLoading {
            // Page finished loading (handle case where didFinish wasn't called)
            if let json = co.pendingStateRestore {
                let js = restoreStateJS.replacingOccurrences(of: "STATES_PLACEHOLDER", with: json)
                webView.evaluateJavaScript(js, completionHandler: nil)
                co.pendingStateRestore = nil
            }
        }
    }

    /// Inject jQuery + pycmd polyfill at document start.
    private static var jQueryScript: WKUserScript {
        let polyfill = """
        (function() {
            if (!window.pycmd) {
                window.pycmd = function(cmd) {
                    try { window.webkit.messageHandlers.pycmd.postMessage(String(cmd)); } catch(e) {}
                };
            }
            if (!window.py) {
                window.py = window.pycmd;
            }
        })();
        """
        let source = embeddedJQuery + "\n" + polyfill
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    private static var viewportScript: WKUserScript {
        let source = """
        var meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, user-scalable=no';
        document.head.appendChild(meta);
        """
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }

    private static var consoleCaptureScript: WKUserScript {
        let source = """
        (function() {
            if (window._consoleCaptured) return;
            window._consoleCaptured = true;
            ['log', 'warn', 'error'].forEach(function(level) {
                var orig = console[level];
                console[level] = function() {
                    var args = Array.from(arguments).map(function(a) {
                        try { return typeof a === 'object' ? JSON.stringify(a) : String(a); } catch(e) { return String(a); }
                    });
                    try {
                        window.webkit.messageHandlers[level].postMessage(args.join(' '));
                    } catch(e) {}
                    orig.apply(console, arguments);
                };
            });
            window.onerror = function(msg, url, line, col, err) {
                try { window.webkit.messageHandlers['error'].postMessage('UNCAUGHT: ' + msg + ' at ' + url + ':' + line); } catch(e) {}
            };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
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
