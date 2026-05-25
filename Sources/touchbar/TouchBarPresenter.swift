import AppKit
import SwiftUI
import Foundation

@MainActor
public final class TouchBarPresenter: NSObject, NSTouchBarDelegate {
    @objc public static let shared = TouchBarPresenter()
    
    private let trayIdentifier = "com.touchbarcraft.systemtray"
    private var systemTrayItem: NSCustomTouchBarItem?
    private var globalTouchBar: NSTouchBar?
    
    // Map widget ID -> widget for button action dispatch
    private var widgetMap: [String: TouchBarWidget] = [:]
    
    // Private framework loaders
    private typealias DFRElementSetControlStripPresenceForIdentifierType = @convention(c) (CFString, Bool) -> Void
    private typealias DFRSystemModalShowsCloseBoxWhenFrontMostType = @convention(c) (Bool) -> Void
    
    private var dfrelementSetControlStripPresenceForIdentifier: DFRElementSetControlStripPresenceForIdentifierType? {
        let handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW)
        guard let sym = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") else { return nil }
        return unsafeBitCast(sym, to: DFRElementSetControlStripPresenceForIdentifierType.self)
    }
    
    private var dfrSystemModalShowsCloseBoxWhenFrontMost: DFRSystemModalShowsCloseBoxWhenFrontMostType? {
        let handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW)
        guard let sym = dlsym(handle, "DFRSystemModalShowsCloseBoxWhenFrontMost") else { return nil }
        return unsafeBitCast(sym, to: DFRSystemModalShowsCloseBoxWhenFrontMostType.self)
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup System Tray Item
    
    @objc public func setupSystemTrayItem() {
        removeSystemTrayItem()
        
        let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier(trayIdentifier))
        
        let button = NSButton(
            image: NSImage(systemSymbolName: "sparkles", accessibilityDescription: "TouchBarCraft") ?? NSImage(),
            target: self,
            action: #selector(systemTrayButtonTapped)
        )
        button.bezelStyle = .rounded
        item.view = button
        self.systemTrayItem = item
        
        let addSelector = NSSelectorFromString("addSystemTrayItem:")
        if NSTouchBarItem.responds(to: addSelector) {
            NSTouchBarItem.perform(addSelector, with: item)
        }
        
        dfrelementSetControlStripPresenceForIdentifier?(trayIdentifier as CFString, true)
    }
    
    public func removeSystemTrayItem() {
        guard let item = systemTrayItem else { return }
        
        dfrelementSetControlStripPresenceForIdentifier?(trayIdentifier as CFString, false)
        
        let removeSelector = NSSelectorFromString("removeSystemTrayItem:")
        if NSTouchBarItem.responds(to: removeSelector) {
            NSTouchBarItem.perform(removeSelector, with: item)
        }
        
        self.systemTrayItem = nil
    }
    
    @objc private func systemTrayButtonTapped() {
        presentGlobalTouchBar()
    }
    
    // MARK: - Present / Dismiss System-Wide Touch Bar
    
    @objc public func presentGlobalTouchBar() {
        guard let state = AppState.shared else { return }
        
        // Build widget lookup map
        widgetMap.removeAll()
        for widget in state.widgets {
            widgetMap[widget.id.uuidString] = widget
        }
        
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = state.widgets.map { NSTouchBarItem.Identifier($0.id.uuidString) }
        
        self.globalTouchBar = touchBar
        
        dfrSystemModalShowsCloseBoxWhenFrontMost?(true)
        
        let presentSelector = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
        if NSTouchBar.responds(to: presentSelector) {
            NSTouchBar.perform(presentSelector, with: touchBar, with: trayIdentifier)
            print("System-wide Touch Bar successfully presented!")
        } else {
            print("Failed to resolve presentSystemModalTouchBar selector.")
        }
    }
    
    @objc public func dismissGlobalTouchBar() {
        guard let touchBar = globalTouchBar else { return }
        
        let dismissSelector = NSSelectorFromString("dismissSystemModalTouchBar:")
        if NSTouchBar.responds(to: dismissSelector) {
            NSTouchBar.perform(dismissSelector, with: touchBar)
            print("System-wide Touch Bar dismissed.")
        }
        
        self.globalTouchBar = nil
    }
    
    @objc public static func refreshTouchBar() {
        DispatchQueue.main.async {
            let presenter = TouchBarPresenter.shared
            if presenter.globalTouchBar != nil {
                presenter.presentGlobalTouchBar()
            }
        }
    }
    
    // MARK: - Button Action Dispatch (called by native NSButton targets)
    
    @objc private func touchBarButtonTapped(_ sender: NSButton) {
        let widgetID = String(sender.tag)
        // Tag stores hash; find the widget via identifier stored in accessibilityIdentifier
        let identifier = sender.accessibilityIdentifier() ?? ""
        guard let widget = widgetMap[identifier] else { return }
        guard let state = AppState.shared else { return }
        state.executeAction(for: widget)
    }
    
    @objc private func mediaPlayPause(_ sender: NSButton) {
        executeMediaCommand("playpause")
    }
    
    @objc private func mediaNext(_ sender: NSButton) {
        executeMediaCommand("next")
    }
    
    @objc private func mediaPrevious(_ sender: NSButton) {
        executeMediaCommand("previous")
    }
    
    @objc private func ankiConnectTapped(_ sender: NSButton) {
        guard let state = AppState.shared else { return }
        state.ankiState.checkConnection()
    }
    
    @objc private func ankiRevealTapped(_ sender: NSButton) {
        guard let state = AppState.shared else { return }
        state.ankiState.revealAnswer()
    }
    
    @objc private func ankiRatingTapped(_ sender: NSButton) {
        guard let state = AppState.shared else { return }
        let rating = sender.tag
        state.ankiState.submitRating(ease: rating)
    }
    
    private func executeMediaCommand(_ action: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var scriptString = ""
            switch action {
            case "playpause":
                scriptString = """
                if application "Music" is running then
                    tell application "Music" to playpause
                else if application "Spotify" is running then
                    tell application "Spotify" to playpause
                end if
                """
            case "next":
                scriptString = """
                if application "Music" is running then
                    tell application "Music" to next track
                else if application "Spotify" is running then
                    tell application "Spotify" to next track
                end if
                """
            case "previous":
                scriptString = """
                if application "Music" is running then
                    tell application "Music" to previous track
                else if application "Spotify" is running then
                    tell application "Spotify" to previous track
                end if
                """
            default:
                break
            }
            if !scriptString.isEmpty, let script = NSAppleScript(source: scriptString) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
        }
    }
    
    // MARK: - NSTouchBarDelegate
    
    public func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard let state = AppState.shared else { return nil }
        guard let widget = state.widgets.first(where: { $0.id.uuidString == identifier.rawValue }) else { return nil }
        
        let item = NSCustomTouchBarItem(identifier: identifier)
        
        switch widget.type {
        case .button:
            // Use native NSButton so touch events fire correctly in system modal
            let button = makeNativeButton(for: widget, state: state)
            item.view = button
            
        case .media:
            // Use native NSButtons for media controls
            let stack = makeNativeMediaControls(for: widget)
            item.view = stack
            
        case .label:
            // Display-only: NSHostingView is fine
            let hostView = NSHostingView(rootView:
                WidgetLabelView(widget: widget, state: state, isSimulator: false)
                    .frame(height: 30)
            )
            item.view = hostView
            
        case .systemMonitor:
            let hostView = NSHostingView(rootView:
                WidgetSystemMonitorView(widget: widget, state: state, isSimulator: false)
                    .frame(height: 30)
            )
            item.view = hostView
            
        case .animation:
            let hostView = NSHostingView(rootView:
                WidgetAnimationView(widget: widget, state: state, isSimulator: false)
                    .frame(height: 30)
            )
            item.view = hostView
            
        case .anki:
            let ankiView = makeNativeAnkiView(for: widget, state: state)
            item.view = ankiView
        }
        
        return item
    }
    
    // MARK: - Native Button Factories
    
    private func makeNativeButton(for widget: TouchBarWidget, state: AppState) -> NSButton {
        let title = parseTemplate(title: widget.title, state: state)
        
        let button: NSButton
        if let img = NSImage(systemSymbolName: widget.iconName, accessibilityDescription: widget.title), !widget.iconName.isEmpty {
            if !title.isEmpty {
                button = NSButton(title: title, image: img, target: self, action: #selector(touchBarButtonTapped(_:)))
                button.imagePosition = .imageLeading
            } else {
                button = NSButton(image: img, target: self, action: #selector(touchBarButtonTapped(_:)))
            }
        } else {
            button = NSButton(title: title, target: self, action: #selector(touchBarButtonTapped(_:)))
        }
        
        // Store widget ID in accessibilityIdentifier for lookup on tap
        button.setAccessibilityIdentifier(widget.id.uuidString)
        
        // Styling
        button.bezelStyle = .rounded
        button.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
        button.contentTintColor = NSColor(Color(hex: widget.textColorHex))
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        
        return button
    }
    
    private func makeNativeMediaControls(for widget: TouchBarWidget) -> NSStackView {
        let prevBtn = NSButton(
            image: NSImage(systemSymbolName: "backward.fill", accessibilityDescription: "Previous") ?? NSImage(),
            target: self,
            action: #selector(mediaPrevious(_:))
        )
        prevBtn.bezelStyle = .rounded
        prevBtn.isBordered = false
        
        let playBtn = NSButton(
            image: NSImage(systemSymbolName: "playpause.fill", accessibilityDescription: "Play/Pause") ?? NSImage(),
            target: self,
            action: #selector(mediaPlayPause(_:))
        )
        playBtn.bezelStyle = .rounded
        playBtn.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
        playBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex))
        
        let nextBtn = NSButton(
            image: NSImage(systemSymbolName: "forward.fill", accessibilityDescription: "Next") ?? NSImage(),
            target: self,
            action: #selector(mediaNext(_:))
        )
        nextBtn.bezelStyle = .rounded
        nextBtn.isBordered = false
        
        let stack = NSStackView(views: [prevBtn, playBtn, nextBtn])
        stack.orientation = .horizontal
        stack.spacing = 4
        
        return stack
    }
    
    private func makeNativeAnkiView(for widget: TouchBarWidget, state: AppState) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        
        let anki = state.ankiState
        
        if !anki.isConnected {
            let label = NSTextField(labelWithString: "Anki Offline")
            label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = NSColor(Color(hex: widget.textColorHex))
            
            let btn = NSButton(title: "Connect", target: self, action: #selector(ankiConnectTapped(_:)))
            btn.bezelStyle = .rounded
            btn.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
            btn.contentTintColor = NSColor(Color(hex: widget.textColorHex))
            
            stack.addArrangedSubview(label)
            stack.addArrangedSubview(btn)
            return stack
        }
        
        guard let card = anki.currentCard else {
            let label = NSTextField(labelWithString: "Anki: Select Deck")
            label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = NSColor(Color(hex: widget.textColorHex))
            
            stack.addArrangedSubview(label)
            return stack
        }
        
        if !anki.isShowingAnswer {
            let label = NSTextField(labelWithString: "Q: \(card.question)")
            label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = NSColor(Color(hex: widget.textColorHex))
            label.lineBreakMode = .byTruncatingTail
            
            let btn = NSButton(title: "Reveal ▶", target: self, action: #selector(ankiRevealTapped(_:)))
            btn.bezelStyle = .rounded
            btn.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
            btn.contentTintColor = NSColor(Color(hex: widget.textColorHex))
            
            stack.addArrangedSubview(label)
            stack.addArrangedSubview(btn)
        } else {
            let label = NSTextField(labelWithString: "A: \(card.answer)")
            label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = NSColor(Color(hex: widget.textColorHex))
            label.lineBreakMode = .byTruncatingTail
            stack.addArrangedSubview(label)
            
            let count = card.buttonCount
            let labels = ["Again", "Hard", "Good", "Easy"]
            let colors = [
                NSColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0),
                NSColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1.0),
                NSColor(red: 0.1, green: 0.7, blue: 0.3, alpha: 1.0),
                NSColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
            ]
            
            for i in 0..<min(count, 4) {
                let rating = i + 1
                let title = labels[i]
                let btn = NSButton(title: title, target: self, action: #selector(ankiRatingTapped(_:)))
                btn.tag = rating
                btn.bezelStyle = .rounded
                btn.bezelColor = colors[i]
                btn.contentTintColor = .white
                btn.font = NSFont.systemFont(ofSize: 11, weight: .bold)
                stack.addArrangedSubview(btn)
            }
        }
        
        return stack
    }
}

