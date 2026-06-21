import AppKit
import SwiftUI
import Foundation

// MARK: - Anki Touch Bar Layout Configuration

struct AnkiTouchBarConfig {
    var isMediaOnLeft: Bool
    
    private static let toggleKey = "AnkiTouchBar.isMediaOnLeft"
    
    static var storedIsMediaOnLeft: Bool {
        get { UserDefaults.standard.bool(forKey: toggleKey) }
        set { UserDefaults.standard.set(newValue, forKey: toggleKey) }
    }
    
    static var current: AnkiTouchBarConfig {
        AnkiTouchBarConfig(isMediaOnLeft: storedIsMediaOnLeft)
    }
}

@objc protocol NSTouchBarPrivate {
    static func presentSystemModalTouchBar(_ touchBar: NSTouchBar, placement: Int64, systemTrayItemIdentifier: String)
    static func presentSystemModalTouchBar(_ touchBar: NSTouchBar, systemTrayItemIdentifier: String)
    static func dismissSystemModalTouchBar(_ touchBar: NSTouchBar)
    static func minimizeSystemModalTouchBar(_ touchBar: NSTouchBar)
}

@MainActor
public final class TouchBarPresenter: NSObject, NSTouchBarDelegate, NSGestureRecognizerDelegate {
    @objc public static let shared = TouchBarPresenter()
    
    private let trayIdentifier = "com.touchbarcraft.systemtray"
    private var systemTrayItem: NSCustomTouchBarItem?
    private var globalTouchBar: NSTouchBar?
    
    // Map widget ID -> widget for button action dispatch
    private var widgetMap: [String: TouchBarWidget] = [:]
    
    // Weak references to volume sliders for live updates
    private static let volumeSliders = NSHashTable<NSSlider>.weakObjects()
    private static var lastVolumeValue: Double = -1
    private var volumePollingTimer: Timer?
    
    // Key for associated object on silent rating buttons
    private var ratingTagKey: UInt8 = 0
    // Key for associated object on scrollable label leading constraint
    private static var scrollableLeadingKey: UInt8 = 0
    
    /// Lightweight view that clips subviews to its bounds via draw-time clipping.
    /// Avoids `wantsLayer` + `masksToBounds` which can cause NSTextField rendering issues on the Touch Bar.
    private class ClippingView: NSView {
        override func draw(_ dirtyRect: NSRect) {
            NSBezierPath(rect: bounds).setClip()
            super.draw(dirtyRect)
        }
    }
    
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
        setupWorkspaceNotifications()
        startVolumePolling()
    }
    
    private func startVolumePolling() {
        volumePollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            TouchBarPresenter.refreshVolumeSliders()
        }
    }
    
    private func setupWorkspaceNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivateApplication),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    @objc private func workspaceDidActivateApplication() {
        // Jika Touch Bar kustom kita sedang aktif, tampilkan kembali saat berpindah aplikasi
        if globalTouchBar != nil {
            presentGlobalTouchBar(rebuild: false)
        }
        // Selalu pastikan tombol close (X) tidak muncul ketika Touch Bar aktif
        dfrSystemModalShowsCloseBoxWhenFrontMost?(false)
        for delay in [0.01, 0.05, 0.1, 0.2, 0.3, 0.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.dfrSystemModalShowsCloseBoxWhenFrontMost?(false)
            }
        }
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
        presentGlobalTouchBar(rebuild: true)
    }
    
    // MARK: - Present / Dismiss System-Wide Touch Bar
    
    @objc public func presentGlobalTouchBar() {
        presentGlobalTouchBar(rebuild: true)
    }
    
    public func presentGlobalTouchBar(rebuild: Bool) {
        guard let state = AppState.shared else { return }
        
        // Build widget lookup map
        widgetMap.removeAll()
        for widget in state.widgets {
            widgetMap[widget.id.uuidString] = widget
        }
        
        // Disable the close box (X button) in DFRFoundation
        dfrSystemModalShowsCloseBoxWhenFrontMost?(false)
        
        let touchBar: NSTouchBar
        if !rebuild, let existing = self.globalTouchBar {
            touchBar = existing
        } else {
            touchBar = NSTouchBar()
            touchBar.delegate = self
            touchBar.defaultItemIdentifiers = state.widgets
                .filter { !$0.isHidden }
                .map { NSTouchBarItem.Identifier($0.id.uuidString) }
            self.globalTouchBar = touchBar
        }
        
        let privateClass = unsafeBitCast(NSTouchBar.self, to: NSTouchBarPrivate.Type.self)
        privateClass.presentSystemModalTouchBar(touchBar, placement: 1, systemTrayItemIdentifier: trayIdentifier)
        
        // Call it again after presentation to ensure macOS doesn't override it
        dfrSystemModalShowsCloseBoxWhenFrontMost?(false)
        print("System-wide Touch Bar successfully presented with placement: 1 (rebuild: \(rebuild))!")
    }
    
    @objc public func dismissGlobalTouchBar() {
        guard let touchBar = globalTouchBar else { return }
        
        let privateClass = unsafeBitCast(NSTouchBar.self, to: NSTouchBarPrivate.Type.self)
        privateClass.dismissSystemModalTouchBar(touchBar)
        print("System-wide Touch Bar dismissed.")
        
        self.globalTouchBar = nil
    }
    
    @objc public static func refreshTouchBar() {
        print("[ScrollText] refreshTouchBar called")
        DispatchQueue.main.async {
            print("[ScrollText] refreshTouchBar executing on main")
            let presenter = TouchBarPresenter.shared
            if presenter.globalTouchBar != nil {
                presenter.presentGlobalTouchBar()
            }
            // Ensure close button stays hidden
            presenter.dfrSystemModalShowsCloseBoxWhenFrontMost?(false)
            // Refresh NHK floating window if visible
            NHKFloatingWindowManager.shared.refreshContent()
        }
    }
    
    // MARK: - Button Action Dispatch (called by native NSButton targets)
    
    @objc private func touchBarButtonTapped(_ sender: NSButton) {
        let identifier = sender.accessibilityIdentifier()
        guard let state = AppState.shared else { return }
        guard let widget = state.widgets.first(where: { $0.id.uuidString == identifier }) else { return }
        state.executeAction(for: widget, isLongPress: false)
    }
    
    @objc private func widgetTapped(_ gesture: NSGestureRecognizer) {
        guard let identifier = gesture.view?.accessibilityIdentifier() else { return }
        guard let state = AppState.shared else { return }
        guard let widget = state.widgets.first(where: { $0.id.uuidString == identifier }) else { return }
        state.executeAction(for: widget, isLongPress: false)
    }
    
    @objc private func widgetLongPressed(_ gesture: NSPressGestureRecognizer) {
        if gesture.state == .began {
            guard let identifier = gesture.view?.accessibilityIdentifier() else { return }
            guard let state = AppState.shared else { return }
            guard let widget = state.widgets.first(where: { $0.id.uuidString == identifier }) else { return }
            state.executeAction(for: widget, isLongPress: true)
        }
    }
    
    @objc private func widgetSwiped(_ gesture: NSGestureRecognizer) {
        guard gesture.state == .ended || gesture.state == .recognized else { return }
        guard let swipe = gesture as? MultiFingerSwipeGestureRecognizer else { return }
        
        let translation = swipe.translation
        let horizontalDistance = abs(translation.x)
        let verticalDistance = abs(translation.y)
        
        guard horizontalDistance > 30 else { return }
        guard horizontalDistance > verticalDistance * 2 else { return }
        
        guard let state = AppState.shared else { return }
        
        let isLeftSwipe = translation.x < 0
        let actionType: ActionType
        if swipe.numberOfTouchesRequired == 2 {
            actionType = isLeftSwipe ? state.swipe2LeftActionType : state.swipe2RightActionType
        } else {
            actionType = isLeftSwipe ? state.swipe3LeftActionType : state.swipe3RightActionType
        }
        guard actionType != .none else { return }
        
        state.executeSwipeAction(actionType)
    }
    
    // Pan gesture handler for scrollable text labels
    @objc private func handleLabelPan(_ gesture: NSPanGestureRecognizer) {
        guard let clipView = gesture.view,
              let leading = objc_getAssociatedObject(clipView, &TouchBarPresenter.scrollableLeadingKey) as? NSLayoutConstraint,
              let textView = clipView.subviews.first else { return }
        
        let translation = gesture.translation(in: clipView)
        gesture.setTranslation(.zero, in: clipView)
        
        let clipWidth = clipView.bounds.width
        let textWidth = textView.frame.width
        
        if gesture.state == .began {
            print("[ScrollText] PAN BEGAN clipWidth=\(clipWidth) textWidth=\(textWidth) clipFrame=\(clipView.frame) textFrame=\(textView.frame)")
        }
        
        guard textWidth > clipWidth else {
            leading.constant = 0
            return
        }
        
        var offset = leading.constant + translation.x
        offset = min(0, max(clipWidth - textWidth, offset))
        leading.constant = offset
        clipView.needsLayout = true
        clipView.layoutSubtreeIfNeeded()
    }
    
    private func configureSwipeGesture(for view: NSView, identifier: String) {
        if view.accessibilityIdentifier().isEmpty {
            view.setAccessibilityIdentifier(identifier)
        }
        addSwipeRecognizer(to: view, fingerCount: 2)
        addSwipeRecognizer(to: view, fingerCount: 3)
    }
    
    private func addSwipeRecognizer(to view: NSView, fingerCount: Int) {
        let swipeGesture = MultiFingerSwipeGestureRecognizer(target: self, action: #selector(widgetSwiped(_:)))
        swipeGesture.numberOfTouchesRequired = fingerCount
        swipeGesture.allowedTouchTypes = .direct
        swipeGesture.delegate = self
        view.addGestureRecognizer(swipeGesture)
    }
    
    public func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: - Custom multi-finger swipe gesture recognizer for Touch Bar
    
    private class MultiFingerSwipeGestureRecognizer: NSGestureRecognizer {
        var numberOfTouchesRequired: Int = 2
        private(set) var translation: NSPoint = .zero
        private var activeTouches: [NSObject: NSTouch] = [:]
        private var initialCentroid: NSPoint = .zero
        
        override func touchesBegan(with event: NSEvent) {
            let touches = event.touches(matching: .began, in: view)
            for touch in touches {
                activeTouches[touch.identity as! NSObject] = touch
            }
            initialCentroid = computeCentroid()
        }
        
        override func touchesMoved(with event: NSEvent) {
            let moved = event.touches(matching: .moved, in: view)
            for touch in moved {
                activeTouches[touch.identity as! NSObject] = touch
            }
            
            guard activeTouches.count == numberOfTouchesRequired else { return }
            
            let centroid = computeCentroid()
            translation = NSPoint(x: centroid.x - initialCentroid.x, y: centroid.y - initialCentroid.y)
            
            if state == .possible && shouldRecognize() {
                state = .began
                state = .ended
            }
        }
        
        override func touchesEnded(with event: NSEvent) {
            let ended = event.touches(matching: .ended, in: view)
            for touch in ended {
                activeTouches.removeValue(forKey: touch.identity as! NSObject)
            }
            if state == .began || state == .changed {
                state = .ended
            } else if activeTouches.isEmpty && shouldRecognize() {
                state = .recognized
            }
        }
        
        override func touchesCancelled(with event: NSEvent) {
            activeTouches.removeAll()
            translation = .zero
            state = .cancelled
        }
        
        override func reset() {
            super.reset()
            activeTouches.removeAll()
            translation = .zero
        }
        
        private func shouldRecognize() -> Bool {
            let horizontal = abs(translation.x)
            let vertical = abs(translation.y)
            return horizontal > 30 && horizontal > vertical * 2
        }
        
        private func computeCentroid() -> NSPoint {
            guard !activeTouches.isEmpty else { return .zero }
            var sumX: CGFloat = 0
            var sumY: CGFloat = 0
            for touch in activeTouches.values {
                let loc = touch.location(in: view)
                sumX += loc.x
                sumY += loc.y
            }
            let count = CGFloat(activeTouches.count)
            return NSPoint(x: sumX / count, y: sumY / count)
        }
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
    
    @objc private func ankiRevealTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.ankiState.revealAnswer()
    }
    
    @objc private func ankiRatingTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        let view: NSView?
        if let gesture = sender as? NSGestureRecognizer {
            view = gesture.view
        } else if let btn = sender as? NSButton {
            view = btn
        } else {
            view = sender as? NSView
        }
        let rating = view?.tag ?? 0
        guard rating > 0 else { return }
        state.ankiState.submitRating(ease: rating)
    }
    
    @objc private func ankiSyncTapped(_ sender: NSButton) {
        guard let state = AppState.shared else { return }
        state.ankiState.syncDecks()
    }
    
    @objc private func ankiAudioToggleTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.ankiState.toggleAudio()
    }
    
    @objc private func ankiTouchBarAudioTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.ankiState.toggleTouchBarAudio()
    }

    @objc private func ankiExtraQuestionTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.ankiState.toggleTouchBarExtraQuestion()
    }

    @objc private func ankiExtraAnswerTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.ankiState.toggleTouchBarExtraAnswer()
    }
    
    // MARK: - Toggle Touch Bar Layout
    
    @objc public func toggleLayout() {
        AnkiTouchBarConfig.storedIsMediaOnLeft.toggle()
        presentGlobalTouchBar(rebuild: true)
        print("Anki Touch Bar layout toggled: mediaOnLeft = \(AnkiTouchBarConfig.storedIsMediaOnLeft)")
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

        if widget.hideFromTouchBar { return nil }

        let item = NSCustomTouchBarItem(identifier: identifier)
        
        switch widget.type {
        case .button:
            // Use native NSButton so touch events fire correctly in system modal
            let button = makeNativeButton(for: widget, state: state)
            
            // Add long press gesture
            let longPress = NSPressGestureRecognizer(target: self, action: #selector(widgetLongPressed(_:)))
            longPress.minimumPressDuration = 0.5
            longPress.allowedTouchTypes = .direct
            button.addGestureRecognizer(longPress)
            
            item.view = button
            
        case .media:
            // Use native NSButtons for media controls
            let stack = makeNativeMediaControls(for: widget)
            item.view = stack
            
        case .label:
            let hostView = NSHostingView(rootView:
                WidgetLabelView(widget: widget, state: state, isSimulator: false)
                    .frame(height: 30)
            )
            let button = TouchBarContainerButton(hostView: hostView, target: self, action: #selector(touchBarButtonTapped(_:)))
            button.setAccessibilityIdentifier(identifier.rawValue)
            
            let longPress = NSPressGestureRecognizer(target: self, action: #selector(widgetLongPressed(_:)))
            longPress.minimumPressDuration = 0.5
            longPress.allowedTouchTypes = .direct
            button.addGestureRecognizer(longPress)
            
            item.view = button
            
        case .systemMonitor:
            let hostView = NSHostingView(rootView:
                WidgetSystemMonitorView(widget: widget, state: state, isSimulator: false)
                    .frame(height: 30)
            )
            let button = TouchBarContainerButton(hostView: hostView, target: self, action: #selector(touchBarButtonTapped(_:)))
            button.setAccessibilityIdentifier(identifier.rawValue)
            
            let longPress = NSPressGestureRecognizer(target: self, action: #selector(widgetLongPressed(_:)))
            longPress.minimumPressDuration = 0.5
            longPress.allowedTouchTypes = .direct
            button.addGestureRecognizer(longPress)
            
            item.view = button
            
        case .animation:
            let animView = makeNativeAnimationView(for: widget)
            item.view = animView
            
        case .anki:
            let ankiView = makeNativeAnkiView(for: widget, state: state)
            item.view = ankiView
            
        case .volumeSlider:
            let volumeView = makeNativeVolumeSlider(for: widget)
            item.view = volumeView
            
        case .brightnessButtons:
            let brightnessView = makeNativeBrightnessControls(for: widget)
            item.view = brightnessView
        case .nhkNews:
            let nhkView = makeNativeNHKNewsView(for: widget)
            item.view = nhkView
        case .dock:
            let dockView = makeNativeDockView(for: widget)
            item.view = dockView
        case .appLauncher:
            let appView = makeNativeAppLauncherView(for: widget)
            item.view = appView
        }
        
        configureSwipeGesture(for: item.view, identifier: identifier.rawValue)
        
        if widget.customWidth > 0.0 {
            let view = item.view
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalToConstant: CGFloat(widget.customWidth)).isActive = true
        }
        
        return item
    }
    
    // MARK: - Native Button Factories
    
    private func makeNativeButton(for widget: TouchBarWidget, state: AppState) -> NSButton {
        let title = parseTemplate(title: widget.title, widget: widget, state: state)
        
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
        button.font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize), weight: .medium)
        
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
        stack.distribution = .fill
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        // Set the total width of the Anki stack based on user's ankiTextMaxWidth setting
        stack.widthAnchor.constraint(equalToConstant: CGFloat(widget.ankiTextMaxWidth + 160)).isActive = true

        let anki = state.ankiState
        let config = AnkiTouchBarConfig.current
        
        if !anki.isConnected {
            let label = NSTextField(labelWithString: "Anki Offline")
            label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = NSColor(Color(hex: widget.textColorHex))
            
            let btn = NSButton(title: "Connect", target: self, action: #selector(ankiConnectTapped(_:)))
            btn.bezelStyle = .rounded
            btn.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
            btn.contentTintColor = NSColor(Color(hex: widget.textColorHex))
            btn.setAccessibilityLabel("Connect to Anki")
            
            stack.addArrangedSubview(label)
            stack.addArrangedSubview(btn)
            return stack
        }
        
        // Build the sync button
        let syncButton = buildSyncButton(for: widget, anki: anki)
        
        guard let card = anki.currentCard else {
            let message = anki.isLoading ? "Anki: Loading..." : (anki.selectedDeck.isEmpty ? "Anki: Select Deck" : "Anki: No cards to study")
            print("[ScrollText] NO CARD — showing '\(message)'")
            let label = NSTextField(labelWithString: message)
            label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = NSColor(Color(hex: widget.textColorHex))

            if config.isMediaOnLeft {
                stack.addArrangedSubview(label)
                stack.addArrangedSubview(syncButton)
            } else {
                stack.addArrangedSubview(syncButton)
                stack.addArrangedSubview(label)
            }
            return stack
        }
        
        if !anki.isShowingAnswer {
            // Build question label
            print("[ScrollText] BUILDING QUESTION — card=\(card.question.prefix(60))... ankiTrimText=\(widget.ankiTrimText)")
            let questionLabel = buildQuestionLabel(for: widget, card: card, anki: anki)
            
            if widget.ankiShowRemainingCounts {
                let controls = buildCountsAndRevealStack(for: widget, anki: anki)
                let spacer = NSView()
                spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                
                if config.isMediaOnLeft {
                    // Left: Counts+Reveal | Label | Spacer | Sync
                    stack.addArrangedSubview(controls)
                    stack.addArrangedSubview(questionLabel)
                    stack.addArrangedSubview(spacer)
                    stack.addArrangedSubview(syncButton)
                } else {
                    // Default: Sync | Label | Spacer | Counts+Reveal
                    stack.addArrangedSubview(syncButton)
                    stack.addArrangedSubview(questionLabel)
                    stack.addArrangedSubview(spacer)
                    stack.addArrangedSubview(controls)
                }
            } else {
                // Container view with background & corner radius (acts as silent button)
                let container = NSView()
                container.wantsLayer = true
                container.layer?.backgroundColor = NSColor(Color(hex: widget.backgroundColorHex)).cgColor
                container.layer?.cornerRadius = 6
                container.setAccessibilityLabel("Reveal Answer")
                container.setContentCompressionResistancePriority(.required, for: .horizontal)
                container.setContentHuggingPriority(.required, for: .horizontal)
                container.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    container.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
                    container.heightAnchor.constraint(equalToConstant: 24)
                ])
                
                // Centered text label inside container
                let revealLabel = NSTextField(labelWithString: "Reveal ▶")
                revealLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                revealLabel.textColor = NSColor(Color(hex: widget.textColorHex))
                revealLabel.alignment = .center
                revealLabel.isBezeled = false
                revealLabel.drawsBackground = false
                revealLabel.isEditable = false
                revealLabel.isSelectable = false
                revealLabel.translatesAutoresizingMaskIntoConstraints = false
                
                container.addSubview(revealLabel)
                NSLayoutConstraint.activate([
                    revealLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    revealLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
                ])
                
                let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(ankiRevealTapped(_:)))
                clickGesture.buttonMask = 1
                clickGesture.allowedTouchTypes = .direct
                container.addGestureRecognizer(clickGesture)
                
                if config.isMediaOnLeft {
                    // Left: Reveal | Label | Spacer | Sync
                    let labelSpacer = NSView()
                    labelSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                    labelSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    stack.addArrangedSubview(container)
                    stack.addArrangedSubview(questionLabel)
                    stack.addArrangedSubview(labelSpacer)
                    stack.addArrangedSubview(syncButton)
                } else {
                    // Default: Sync | Label | Reveal
                    stack.addArrangedSubview(syncButton)
                    stack.addArrangedSubview(questionLabel)
                    stack.addArrangedSubview(container)
                }
            }
        } else {
            // Build answer label
            let answerLabel = buildAnswerLabel(for: widget, card: card, anki: anki)
            
            // Build rating buttons
            let count = card.buttonCount
            let buttonsToShow = getRatingButtons(for: widget, buttonCount: count, intervals: anki.buttonIntervals, labels: anki.buttonLabels, showInterval: widget.ankiShowButtonsInterval)
            var ratingButtonViews: [NSView] = []
            if widget.ankiShowButtonsInterval {
                // Vertical layout: small button + interval text below (outside clickable area)
                for btnSpec in buttonsToShow {
                    let parts = btnSpec.title.components(separatedBy: " (")
                    let title = parts[0]
                    let interval = parts.count > 1 ? String(parts[1].dropLast()) : ""

                    let group = NSStackView()
                    group.orientation = .vertical
                    group.spacing = 1
                    group.alignment = .centerX
                    group.distribution = .fill
                    group.translatesAutoresizingMaskIntoConstraints = false

                    let btn = NSButton(title: "", target: self, action: #selector(ankiRatingTapped(_:)))
                    btn.tag = btnSpec.rating
                    btn.bezelStyle = .rounded
                    btn.isBordered = false
                    btn.wantsLayer = true
                    btn.layer?.backgroundColor = btnSpec.color.cgColor
                    btn.layer?.cornerRadius = 4
                    btn.translatesAutoresizingMaskIntoConstraints = false

                    let attrTitle = NSAttributedString(string: title, attributes: [
                        .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                        .foregroundColor: NSColor.white,
                        .paragraphStyle: {
                            let p = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                            p.alignment = .center
                            return p
                        }()
                    ])
                    btn.attributedTitle = attrTitle

                    btn.setContentCompressionResistancePriority(.required, for: .horizontal)
                    btn.setContentHuggingPriority(.required, for: .horizontal)
                    NSLayoutConstraint.activate([
                        btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
                        btn.heightAnchor.constraint(equalToConstant: 17),
                    ])

                    if !interval.isEmpty {
                        let intervalLabel = NSTextField(labelWithString: interval)
                        intervalLabel.font = NSFont.systemFont(ofSize: 7, weight: .medium)
                        intervalLabel.textColor = .white.withAlphaComponent(0.8)
                        intervalLabel.alignment = .center
                        intervalLabel.isBezeled = false
                        intervalLabel.drawsBackground = false
                        intervalLabel.isEditable = false
                        intervalLabel.isSelectable = false
                        intervalLabel.translatesAutoresizingMaskIntoConstraints = false
                        intervalLabel.heightAnchor.constraint(equalToConstant: 9).isActive = true
                        group.addArrangedSubview(intervalLabel)
                    }

                    group.addArrangedSubview(btn)

                    ratingButtonViews.append(group)
                }
            } else {
                // Original layout: standard NSButton
                for btnSpec in buttonsToShow {
                    let btn = NSButton(title: btnSpec.title, target: self, action: #selector(ankiRatingTapped(_:)))
                    btn.tag = btnSpec.rating
                    btn.bezelStyle = .rounded
                    btn.bezelColor = btnSpec.color
                    btn.contentTintColor = .white
                    btn.font = NSFont.systemFont(ofSize: 11, weight: .bold)
                    btn.setAccessibilityLabel("Rate \(btnSpec.title)")
                    btn.setContentCompressionResistancePriority(.required, for: .horizontal)
                    btn.setContentHuggingPriority(.required, for: .horizontal)
                    ratingButtonViews.append(btn)
                }
            }
            
            // Build audio button
            var audioButton: NSButton? = nil
            if card.soundFilename != nil {
                audioButton = NSButton(title: "", target: self, action: #selector(ankiAudioToggleTapped(_:)))
                audioButton!.bezelStyle = .rounded
                audioButton!.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
                let symbolName = anki.isAudioPlaying ? "stop.fill" : "play.fill"
                if let audioImg = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Toggle Audio") {
                    audioButton!.image = audioImg
                    audioButton!.imagePosition = .imageOnly
                } else {
                    audioButton!.title = anki.isAudioPlaying ? "Stop" : "Play"
                }
                audioButton!.setAccessibilityLabel(anki.isAudioPlaying ? "Stop Audio" : "Play Audio")
                audioButton!.translatesAutoresizingMaskIntoConstraints = false
                audioButton!.widthAnchor.constraint(equalToConstant: 30).isActive = true
                audioButton!.setContentCompressionResistancePriority(.required, for: .horizontal)
                audioButton!.setContentHuggingPriority(.required, for: .horizontal)
            }
            

            if config.isMediaOnLeft {
                // Left: Rating+Audio | Label | Sync
                for view in ratingButtonViews {
                    stack.addArrangedSubview(view)
                }
                if let audio = audioButton {
                    stack.addArrangedSubview(audio)
                }
                stack.addArrangedSubview(answerLabel)
                stack.addArrangedSubview(syncButton)
            } else {
                // Default: Sync | Label | Rating+Audio
                stack.addArrangedSubview(syncButton)
                stack.addArrangedSubview(answerLabel)
                for view in ratingButtonViews {
                    stack.addArrangedSubview(view)
                }
                if let audio = audioButton {
                    stack.addArrangedSubview(audio)
                }
            }
        }
        
        return stack
    }
    
    // MARK: - Anki View Building Helpers
    
    private func buildSyncButton(for widget: TouchBarWidget, anki: AnkiState) -> NSButton {
        let syncButton = NSButton(title: "", target: self, action: #selector(ankiSyncTapped(_:)))
        syncButton.bezelStyle = .rounded
        syncButton.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
        syncButton.contentTintColor = NSColor(Color(hex: widget.textColorHex))
        syncButton.setAccessibilityLabel("Sync")
        
        if let syncImage = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Sync") {
            syncButton.image = syncImage
            syncButton.imagePosition = .imageOnly
        } else {
            syncButton.title = "Sync"
        }
        
        syncButton.translatesAutoresizingMaskIntoConstraints = false
        syncButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        syncButton.isEnabled = !anki.isSyncing
        
        return syncButton
    }
    
    // MARK: - Extra Field Helpers

    /// Extract extra field value from card fields by parsing comma-separated field names.
    private func getExtraFieldValue(fieldString: String, card: AnkiCard) -> String {
        guard !fieldString.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        let fieldNames = fieldString.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var values: [String] = []
        for name in fieldNames {
            if let val = card.fields[name] {
                let stripped = stripHTMLPreservingBold(val)
                if !stripped.isEmpty {
                    values.append(stripped)
                }
            }
        }
        return values.joined(separator: " / ")
    }

    /// Check whether the actual raw fields for a comma-separated field spec are all empty.
    /// Unlike `card.question` / `card.answer` (which fall back to Anki's rendered output),
    /// this inspects `card.fields` directly so we can detect truly empty fields.
    private func isCardFieldEmpty(fieldString: String, card: AnkiCard) -> Bool {
        guard !fieldString.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        let fieldNames = fieldString.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for name in fieldNames {
            if let val = card.fields[name] {
                let stripped = val.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !stripped.isEmpty {
                    return false
                }
            }
        }
        return true
    }

    /// Strip HTML tags preserving bold/italic/underline for TouchBar display.
    private func stripHTMLPreservingBold(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<(?!/?(b|strong|i|em|u)\\b)[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Wrap an attributed string text field in a compressible NSView container that applies textVerticalOffset.
    /// Optionally adds a silent click gesture recognizer for Touch Bar tap events (used on answer labels).
    private func makeLabelContainer(attributedString: NSAttributedString, textVerticalOffset: CGFloat, ankiTrimText: Bool = true, addTapGesture: Bool = false, tapTarget: Any? = nil, tapAction: Selector? = nil) -> NSView {
        let label = NSTextField(labelWithString: "")
        label.cell?.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.cell?.wraps = false
        if ankiTrimText {
            let mutable = NSMutableAttributedString(attributedString: attributedString)
            let fullRange = NSRange(location: 0, length: mutable.length)
            mutable.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
                let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                style.lineBreakMode = .byTruncatingTail
                mutable.addAttribute(.paragraphStyle, value: style, range: range)
            }
            label.attributedStringValue = mutable
            label.cell?.truncatesLastVisibleLine = true
        } else {
            label.attributedStringValue = attributedString
        }
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: textVerticalOffset)
        ])
        
        if addTapGesture, let target = tapTarget, let action = tapAction {
            let clickGesture = NSClickGestureRecognizer(target: target, action: action)
            clickGesture.buttonMask = 1
            clickGesture.allowedTouchTypes = .direct
            container.addGestureRecognizer(clickGesture)
        }
        
        return container
    }
    
    private func buildQuestionLabel(for widget: TouchBarWidget, card: AnkiCard, anki: AnkiState) -> NSView {
        let font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize), weight: .medium)
        let textColor = NSColor(Color(hex: widget.textColorHex))
        let boldColor = NSColor(Color(hex: widget.ankiBoldColorHex))
        let typeLabel = card.cardTypeLabel
        let hasType = !typeLabel.isEmpty
        
        let extraQText = getExtraFieldValue(fieldString: widget.ankiExtraQuestionField, card: card)
        let hasExtraQ = !extraQText.isEmpty
        let extraQOnlyOnAnswer = AnkiFloatingOverlayManager.shared.config.extraQuestionOnlyOnAnswer
        let showExtraQ = hasExtraQ && !extraQOnlyOnAnswer && anki.touchBarShowingExtraQuestion
        let tapTogglesExtra = hasExtraQ && !extraQOnlyOnAnswer
        
        let displayText: String
        if showExtraQ {
            displayText = extraQText
        } else {
            displayText = widget.ankiCombineFurigana ? card.question : stripFuriganaBrackets(card.question)
        }
        
        let isEmptyField = showExtraQ
            ? extraQText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : isCardFieldEmpty(fieldString: widget.ankiQuestionField, card: card)
        let placeholder = showExtraQ ? "⚠️ Please fill in the extra question field" : "⚠️ Please fill in the question field"
        let effectiveText = isEmptyField ? placeholder : displayText
        
        let textHasFurigana = effectiveText.contains("[") && effectiveText.contains("]")
        
        let contentView: NSView
        if isEmptyField {
            let label = NSTextField(labelWithString: effectiveText)
            label.font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize), weight: .medium)
            label.textColor = textColor.withAlphaComponent(0.5)
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            contentView = label
        } else if showExtraQ {
            if widget.ankiCombineFurigana && textHasFurigana {
                contentView = buildFuriganaRichLabel(
                    text: effectiveText,
                    fontSize: CGFloat(widget.fontSize),
                    textColor: textColor,
                    boldColor: boldColor,
                    isButton: tapTogglesExtra,
                    buttonAction: tapTogglesExtra ? #selector(ankiExtraQuestionTapped(_:)) : nil,
                    manualFuriFontSize: CGFloat(widget.ankiFuriganaFontSize),
                    verticalOffset: CGFloat(widget.ankiFuriganaVerticalOffset),
                    textVerticalOffset: CGFloat(widget.ankiFuriganaSegmentOffset),
                    ankiTrimText: false,
                    furiganaSegmentOffset: CGFloat(widget.ankiFuriganaSegmentOffset)
                )
            } else {
                let attributed = parseBoldTags(in: effectiveText, defaultFont: font, defaultColor: textColor, boldColor: boldColor)
                contentView = makeLabelContainer(
                    attributedString: attributed,
                    textVerticalOffset: CGFloat(widget.ankiNonFuriganaSegmentOffset),
                    ankiTrimText: false,
                    addTapGesture: tapTogglesExtra,
                    tapTarget: tapTogglesExtra ? self : nil,
                    tapAction: tapTogglesExtra ? #selector(ankiExtraQuestionTapped(_:)) : nil
                )
            }
        } else if widget.ankiCombineFurigana && textHasFurigana {
            contentView = buildFuriganaRichLabel(
                text: effectiveText,
                fontSize: CGFloat(widget.fontSize),
                textColor: textColor,
                boldColor: boldColor,
                isButton: tapTogglesExtra,
                buttonAction: tapTogglesExtra ? #selector(ankiExtraQuestionTapped(_:)) : nil,
                manualFuriFontSize: CGFloat(widget.ankiFuriganaFontSize),
                verticalOffset: CGFloat(widget.ankiFuriganaVerticalOffset),
                textVerticalOffset: CGFloat(widget.ankiFuriganaSegmentOffset),
                ankiTrimText: false,
                furiganaSegmentOffset: CGFloat(widget.ankiFuriganaSegmentOffset)
            )
        } else {
            let attributed = parseBoldTags(in: effectiveText, defaultFont: font, defaultColor: textColor, boldColor: boldColor)
            contentView = makeLabelContainer(
                attributedString: attributed,
                textVerticalOffset: CGFloat(widget.ankiNonFuriganaSegmentOffset),
                ankiTrimText: false,
                addTapGesture: tapTogglesExtra,
                tapTarget: tapTogglesExtra ? self : nil,
                tapAction: tapTogglesExtra ? #selector(ankiExtraQuestionTapped(_:)) : nil
            )
        }
        
        let result: NSView
        if hasType {
            let hStack = NSStackView()
            hStack.orientation = .horizontal
            hStack.spacing = 4
            hStack.alignment = .centerY
            
            let typeColor = NSColor(Color(hex: card.cardTypeColorHex)).withAlphaComponent(0.9)
            let dotView = NSView()
            dotView.wantsLayer = true
            dotView.layer?.cornerRadius = 3
            dotView.layer?.backgroundColor = typeColor.cgColor
            dotView.translatesAutoresizingMaskIntoConstraints = false
            dotView.widthAnchor.constraint(equalToConstant: 6).isActive = true
            dotView.heightAnchor.constraint(equalToConstant: 6).isActive = true
            dotView.setContentCompressionResistancePriority(.required, for: .horizontal)
            dotView.setContentHuggingPriority(.required, for: .horizontal)
            hStack.addArrangedSubview(contentView)
            result = hStack
        } else {
            result = contentView
        }
        
        if widget.ankiScrollMode == .both {
            print("[ScrollText] buildQuestionLabel ankiScrollMode=both textWidth=\(effectiveText.count) chars hasType=\(hasType)")
            
            let clipView = ClippingView()
            clipView.wantsLayer = true
            clipView.layer?.masksToBounds = true
            clipView.translatesAutoresizingMaskIntoConstraints = false
            
            result.wantsLayer = true
            result.translatesAutoresizingMaskIntoConstraints = false
            result.setContentCompressionResistancePriority(.required, for: .horizontal)
            result.setContentHuggingPriority(.required, for: .horizontal)
            
            clipView.addSubview(result)
            let leading = result.leadingAnchor.constraint(equalTo: clipView.leadingAnchor)
            NSLayoutConstraint.activate([
                leading,
                result.topAnchor.constraint(equalTo: clipView.topAnchor),
                result.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),
            ])
            clipView.heightAnchor.constraint(equalTo: result.heightAnchor).isActive = true
            
            let pan = NSPanGestureRecognizer(target: self, action: #selector(handleLabelPan(_:)))
            pan.allowedTouchTypes = .direct
            pan.delegate = self
            clipView.addGestureRecognizer(pan)
            objc_setAssociatedObject(clipView, &TouchBarPresenter.scrollableLeadingKey, leading, .OBJC_ASSOCIATION_RETAIN)
            
            // Log frames after first layout pass
            DispatchQueue.main.async {
                print("[ScrollText] POST-LAYOUT clipView.frame=\(clipView.frame) result.frame=\(result.frame) result.intrinsic=\(result.intrinsicContentSize)")
            }
            
            return clipView
        }
        
        return result
    }
    
    private func buildAnswerLabel(for widget: TouchBarWidget, card: AnkiCard, anki: AnkiState) -> NSView {
        let font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize), weight: .medium)
        let textColor = NSColor(Color(hex: widget.textColorHex))
        let boldColor = NSColor(Color(hex: widget.ankiBoldColorHex))
        
        let extraAText = getExtraFieldValue(fieldString: widget.ankiExtraAnswerField, card: card)
        let hasExtraA = !extraAText.isEmpty
        let showExtraA = hasExtraA && widget.ankiTapShowsExtra && anki.touchBarShowingExtraAnswer
        let tapIsExtra = hasExtraA && widget.ankiTapShowsExtra
        
        let displayText: String
        if showExtraA {
            displayText = extraAText
        } else {
            displayText = card.answer
        }
        
        let isEmptyField = showExtraA
            ? extraAText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : isCardFieldEmpty(fieldString: widget.ankiAnswerField, card: card)
        let placeholder = showExtraA ? "⚠️ Please fill in the extra answer field" : "⚠️ Please fill in the answer field"
        let effectiveText = isEmptyField ? placeholder : displayText
        let textHasFurigana = effectiveText.contains("[") && effectiveText.contains("]")
        
        let content: NSView
        if isEmptyField {
            let label = NSTextField(labelWithString: effectiveText)
            label.font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize), weight: .medium)
            label.textColor = textColor.withAlphaComponent(0.5)
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            content = label
        } else if showExtraA {
            if widget.ankiCombineFurigana && textHasFurigana {
                content = buildFuriganaRichLabel(
                    text: effectiveText,
                    fontSize: CGFloat(widget.fontSize),
                    textColor: textColor,
                    boldColor: boldColor,
                    isButton: true,
                    buttonAction: #selector(ankiExtraAnswerTapped(_:)),
                    manualFuriFontSize: CGFloat(widget.ankiFuriganaFontSize),
                    verticalOffset: CGFloat(widget.ankiFuriganaVerticalOffset),
                    textVerticalOffset: CGFloat(widget.ankiFuriganaSegmentOffset),
                    ankiTrimText: false,
                    furiganaSegmentOffset: CGFloat(widget.ankiFuriganaSegmentOffset)
                )
            } else {
                let attributed = parseBoldTags(in: effectiveText, defaultFont: font, defaultColor: textColor, boldColor: boldColor)
                content = makeLabelContainer(
                    attributedString: attributed,
                    textVerticalOffset: CGFloat(widget.ankiNonFuriganaSegmentOffset),
                    ankiTrimText: false,
                    addTapGesture: true,
                    tapTarget: self,
                    tapAction: #selector(ankiExtraAnswerTapped(_:))
                )
            }
        } else if tapIsExtra && widget.ankiCombineFurigana && textHasFurigana {
            content = buildFuriganaRichLabel(
                text: effectiveText,
                fontSize: CGFloat(widget.fontSize),
                textColor: textColor,
                boldColor: boldColor,
                isButton: true,
                buttonAction: #selector(ankiExtraAnswerTapped(_:)),
                manualFuriFontSize: CGFloat(widget.ankiFuriganaFontSize),
                verticalOffset: CGFloat(widget.ankiFuriganaVerticalOffset),
                textVerticalOffset: CGFloat(widget.ankiFuriganaSegmentOffset),
                ankiTrimText: false,
                furiganaSegmentOffset: CGFloat(widget.ankiFuriganaSegmentOffset)
            )
        } else if widget.ankiCombineFurigana && textHasFurigana {
            content = buildFuriganaRichLabel(
                text: effectiveText,
                fontSize: CGFloat(widget.fontSize),
                textColor: textColor,
                boldColor: boldColor,
                isButton: true,
                buttonAction: #selector(ankiTouchBarAudioTapped(_:)),
                manualFuriFontSize: CGFloat(widget.ankiFuriganaFontSize),
                verticalOffset: CGFloat(widget.ankiFuriganaVerticalOffset),
                textVerticalOffset: CGFloat(widget.ankiFuriganaSegmentOffset),
                ankiTrimText: false,
                furiganaSegmentOffset: CGFloat(widget.ankiFuriganaSegmentOffset)
            )
        } else {
            let attributed = parseBoldTags(in: effectiveText, defaultFont: font, defaultColor: textColor, boldColor: boldColor)
            content = makeLabelContainer(
                attributedString: attributed,
                textVerticalOffset: CGFloat(widget.ankiNonFuriganaSegmentOffset),
                ankiTrimText: false,
                addTapGesture: true,
                tapTarget: self,
                tapAction: tapIsExtra ? #selector(ankiExtraAnswerTapped(_:)) : #selector(ankiTouchBarAudioTapped(_:))
            )
        }
        
        if widget.ankiScrollMode == .answerOnly || widget.ankiScrollMode == .both {
            print("[ScrollText] buildAnswerLabel ankiScrollMode=\(widget.ankiScrollMode.rawValue) contentSize=\(content.frame.size)")
            
            let clipView = ClippingView()
            clipView.wantsLayer = true
            clipView.layer?.masksToBounds = true
            clipView.translatesAutoresizingMaskIntoConstraints = false
            
            content.wantsLayer = true
            content.translatesAutoresizingMaskIntoConstraints = false
            content.setContentCompressionResistancePriority(.required, for: .horizontal)
            content.setContentHuggingPriority(.required, for: .horizontal)
            
            clipView.addSubview(content)
            let leading = content.leadingAnchor.constraint(equalTo: clipView.leadingAnchor)
            NSLayoutConstraint.activate([
                leading,
                content.topAnchor.constraint(equalTo: clipView.topAnchor),
                content.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),
            ])
            clipView.heightAnchor.constraint(equalTo: content.heightAnchor).isActive = true
            
            let pan = NSPanGestureRecognizer(target: self, action: #selector(handleLabelPan(_:)))
            pan.allowedTouchTypes = .direct
            pan.delegate = self
            clipView.addGestureRecognizer(pan)
            objc_setAssociatedObject(clipView, &TouchBarPresenter.scrollableLeadingKey, leading, .OBJC_ASSOCIATION_RETAIN)
            
            DispatchQueue.main.async {
                print("[ScrollText] POST-LAYOUT answer clipView.frame=\(clipView.frame) content.frame=\(content.frame) content.intrinsic=\(content.intrinsicContentSize)")
            }
            
            return clipView
        }
        
        return content
    }
    
    /// Build a rich text view with furigana ruby annotations using vertical NSStackView.
    /// Parses both HTML tags (bold/italic/underline) and furigana [furi] patterns.
    /// Uses vertical stacking with zero spacing so furigana sits directly above kanji.
    private func buildFuriganaRichLabel(text: String, fontSize: CGFloat, textColor: NSColor, boldColor: NSColor, isButton: Bool, buttonAction: Selector? = nil, manualFuriFontSize: CGFloat = 0, verticalOffset: CGFloat = 0, textVerticalOffset: CGFloat = 0, ankiTrimText: Bool = true, furiganaColor: NSColor? = nil, furiganaSegmentOffset: CGFloat? = nil) -> NSView {
        // First parse HTML tags into styled chunks (same logic as parseBoldTags)
        struct StyledChunk {
            let text: String
            let isBold: Bool
            let isItalic: Bool
            let isUnderline: Bool
        }
        
        var chunks: [StyledChunk] = []
        var currentText = ""
        var isBold = false
        var isItalic = false
        var isUnderline = false
        
        var index = text.startIndex
        while index < text.endIndex {
            if text[index...].hasPrefix("<b>") || text[index...].hasPrefix("<strong>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if text[index...].hasPrefix("<b>") { index = text.index(index, offsetBy: 3) }
                else { index = text.index(index, offsetBy: 8) }
                isBold = true
            } else if text[index...].hasPrefix("</b>") || text[index...].hasPrefix("</strong>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if text[index...].hasPrefix("</b>") { index = text.index(index, offsetBy: 4) }
                else { index = text.index(index, offsetBy: 9) }
                isBold = false
            } else if text[index...].hasPrefix("<i>") || text[index...].hasPrefix("<em>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if text[index...].hasPrefix("<i>") { index = text.index(index, offsetBy: 3) }
                else { index = text.index(index, offsetBy: 4) }
                isItalic = true
            } else if text[index...].hasPrefix("</i>") || text[index...].hasPrefix("</em>") {
                let hasEmClose = text[index...].hasPrefix("</em>")
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if hasEmClose { index = text.index(index, offsetBy: 5) }
                else { index = text.index(index, offsetBy: 4) }
                isItalic = false
            } else if text[index...].hasPrefix("<u>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                index = text.index(index, offsetBy: 3)
                isUnderline = true
            } else if text[index...].hasPrefix("</u>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                index = text.index(index, offsetBy: 4)
                isUnderline = false
            } else {
                currentText.append(text[index])
                index = text.index(after: index)
            }
        }
        if !currentText.isEmpty {
            chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
        }
        
        // Build horizontal stack with ruby text segments
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.spacing = 0
        hStack.alignment = .centerY
        
        for chunk in chunks {
            let segments = touchbar.parseFuriganaSegments(chunk.text)
            for segment in segments {
                if let furi = segment.furigana {
                    // Ruby segment: kanji label at normal height, furi label overlaid above
                    // Uses NSView container so base label height matches plain text height
                    // Both kanji and furigana must fit within the 30pt Touch Bar
                    let baseFont = NSFont.systemFont(ofSize: fontSize, weight: chunk.isBold ? .bold : .regular)
                    
                    // Determine furigana font size — use user-specified size if set, otherwise auto-calculate
                    let furiFontSize: CGFloat
                    if manualFuriFontSize > 0 {
                        furiFontSize = max(3, manualFuriFontSize)
                    } else {
                        furiFontSize = max(4, fontSize * 0.25)
                    }
                    
                    let container = NSView()
                    container.translatesAutoresizingMaskIntoConstraints = false
                    container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    
                    let baseLabel = NSTextField(labelWithString: segment.text)
                    var font = baseFont
                    if chunk.isItalic {
                        font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                    }
                    baseLabel.font = font
                    baseLabel.textColor = chunk.isBold ? boldColor : textColor
                    baseLabel.alignment = .center
                    baseLabel.isBezeled = false
                    baseLabel.drawsBackground = false
                    baseLabel.isEditable = false
                    baseLabel.isSelectable = false
                    // Always single-line for consistent layout
                baseLabel.cell?.usesSingleLineMode = true
                baseLabel.maximumNumberOfLines = 1
                baseLabel.cell?.wraps = false
                if ankiTrimText {
                    baseLabel.lineBreakMode = .byTruncatingTail
                }
                    baseLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    if chunk.isUnderline {
                        var attrs: [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: chunk.isBold ? boldColor : textColor,
                            .underlineStyle: NSUnderlineStyle.single.rawValue
                        ]
                        if ankiTrimText {
                            let style = NSMutableParagraphStyle()
                            style.lineBreakMode = .byTruncatingTail
                            attrs[.paragraphStyle] = style
                        }
                        baseLabel.attributedStringValue = NSAttributedString(string: segment.text, attributes: attrs)
                    }
                    
                    container.addSubview(baseLabel)
                    baseLabel.translatesAutoresizingMaskIntoConstraints = false
                    let effectiveFuriOffset = furiganaSegmentOffset ?? textVerticalOffset
                    NSLayoutConstraint.activate([
                        baseLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                        baseLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                        baseLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: effectiveFuriOffset)
                    ])
                    
                    let furiLabel = NSTextField(labelWithString: furi)
                    furiLabel.font = NSFont.systemFont(ofSize: furiFontSize, weight: .medium)
                    furiLabel.textColor = furiganaColor ?? (chunk.isBold ? boldColor : textColor).withAlphaComponent(0.65)
                    furiLabel.alignment = .center
                    furiLabel.isBezeled = false
                    furiLabel.drawsBackground = false
                    furiLabel.isEditable = false
                    furiLabel.isSelectable = false
                    furiLabel.cell?.usesSingleLineMode = true
                    furiLabel.maximumNumberOfLines = 1
                    furiLabel.cell?.wraps = false
                    if ankiTrimText {
                        furiLabel.lineBreakMode = .byTruncatingTail
                    }
                    
                    container.addSubview(furiLabel)
                    furiLabel.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        furiLabel.bottomAnchor.constraint(equalTo: baseLabel.topAnchor, constant: -verticalOffset),
                        furiLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor)
                    ])
                    
                    // Ensure container height encompasses both furiLabel and baseLabel
                    let containerTop = furiLabel.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor)
                    containerTop.priority = .required
                    containerTop.isActive = true
                    let containerBottom = baseLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
                    containerBottom.priority = .required
                    containerBottom.isActive = true
                    
                    hStack.addArrangedSubview(container)
                } else {
                    // Plain text segment (no furigana) — wrap in container to apply textVerticalOffset
                    // Trim trailing whitespace to avoid extra spacing after kanji in furigana mode
                    let trimmed = segment.text.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        // Skip whitespace-only segments (spaces before next kanji)
                        continue
                    }
                    let container = NSView()
                    container.translatesAutoresizingMaskIntoConstraints = false
                    container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    
                    let label = NSTextField(labelWithString: trimmed)
                    var baseFont = NSFont.systemFont(ofSize: fontSize, weight: chunk.isBold ? .bold : .regular)
                    if chunk.isItalic {
                        baseFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                    }
                    label.font = baseFont
                    label.textColor = chunk.isBold ? boldColor : textColor
                    label.isBezeled = false
                    label.drawsBackground = false
                    label.isEditable = false
                    label.isSelectable = false
                    label.cell?.usesSingleLineMode = true
                label.maximumNumberOfLines = 1
                label.cell?.wraps = false
                if ankiTrimText {
                    label.lineBreakMode = .byTruncatingTail
                }
                    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    
                    if chunk.isUnderline {
                        var attrs: [NSAttributedString.Key: Any] = [
                            .font: baseFont,
                            .foregroundColor: chunk.isBold ? boldColor : textColor,
                            .underlineStyle: NSUnderlineStyle.single.rawValue
                        ]
                        if ankiTrimText {
                            let style = NSMutableParagraphStyle()
                            style.lineBreakMode = .byTruncatingTail
                            attrs[.paragraphStyle] = style
                        }
                        label.attributedStringValue = NSAttributedString(string: trimmed, attributes: attrs)
                    }
                    
                    container.addSubview(label)
                    label.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                        label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                        label.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: textVerticalOffset)
                    ])
                    
                    hStack.addArrangedSubview(container)
                }
            }
        }
        
        if isButton, let action = buttonAction {
            hStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            hStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            let container = NSStackView(views: [hStack])
            container.orientation = .horizontal
            container.spacing = 0
            container.alignment = .centerY
            container.distribution = .fill
            container.translatesAutoresizingMaskIntoConstraints = false
            
            container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            container.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            let clickGesture = NSClickGestureRecognizer(target: self, action: action)
            clickGesture.buttonMask = 1
            clickGesture.allowedTouchTypes = .direct
            container.addGestureRecognizer(clickGesture)
            
            return container
        }
        
        return hStack
    }
    
    private func buildCountsAndRevealStack(for widget: TouchBarWidget, anki: AnkiState) -> NSStackView {
        let verticalStack = NSStackView()
        verticalStack.orientation = .vertical
        verticalStack.alignment = .centerX
        verticalStack.distribution = .gravityAreas
        verticalStack.spacing = 2
        verticalStack.heightAnchor.constraint(equalToConstant: 28).isActive = true

        // Build counts attributed string (N  L  R in blue/orange/green)
        // Prepend card type label in bold + underline if available
        let countFont = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold)
        let attrStr = NSMutableAttributedString()
        
        // Card type indicator: colored dot with type-specific color
        if let card = anki.currentCard, !card.cardTypeLabel.isEmpty {
            let typeColor = NSColor(Color(hex: card.cardTypeColorHex)).withAlphaComponent(0.9)
            attrStr.append(NSAttributedString(string: "●", attributes: [
                .font: NSFont.systemFont(ofSize: 8),
                .foregroundColor: typeColor
            ]))
            attrStr.append(NSAttributedString(string: "  ", attributes: [.font: countFont]))
        }
        
        attrStr.append(NSAttributedString(string: "\(anki.newCount)", attributes: [
            .font: countFont, .foregroundColor: NSColor.systemBlue
        ]))
        attrStr.append(NSAttributedString(string: "  ", attributes: [.font: countFont]))
        attrStr.append(NSAttributedString(string: "\(anki.learnCount)", attributes: [
            .font: countFont, .foregroundColor: NSColor.systemOrange
        ]))
        attrStr.append(NSAttributedString(string: "  ", attributes: [.font: countFont]))
        attrStr.append(NSAttributedString(string: "\(anki.reviewCount)", attributes: [
            .font: countFont, .foregroundColor: NSColor.systemGreen
        ]))

        let countsLabel = NSTextField(labelWithString: "")
        countsLabel.attributedStringValue = attrStr
        countsLabel.alignment = .center
        countsLabel.isBezeled = false
        countsLabel.drawsBackground = false
        countsLabel.isEditable = false
        countsLabel.isSelectable = false
        countsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        countsLabel.setContentHuggingPriority(.required, for: .horizontal)

        // Reveal button (NSTextField + gesture recognizer, silent — no system click sound)
        let revealLabel = NSTextField(labelWithString: "Reveal ▶")
        revealLabel.font = NSFont.systemFont(ofSize: 7, weight: .semibold)
        revealLabel.textColor = NSColor(Color(hex: widget.textColorHex))
        revealLabel.alignment = .center
        revealLabel.wantsLayer = true
        revealLabel.layer?.backgroundColor = NSColor(Color(hex: widget.backgroundColorHex)).cgColor
        revealLabel.layer?.cornerRadius = 4
        revealLabel.setAccessibilityLabel("Reveal Answer")
        revealLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        revealLabel.setContentHuggingPriority(.required, for: .horizontal)
        revealLabel.translatesAutoresizingMaskIntoConstraints = false
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(ankiRevealTapped(_:)))
        clickGesture.buttonMask = 1
        clickGesture.allowedTouchTypes = .direct
        revealLabel.addGestureRecognizer(clickGesture)

        verticalStack.addArrangedSubview(countsLabel)
        verticalStack.addArrangedSubview(revealLabel)
        
        return verticalStack
    }
    
    private func parseBoldTags(in text: String, defaultFont: NSFont, defaultColor: NSColor, boldColor: NSColor) -> NSAttributedString {
        struct StyledChunk {
            let text: String
            let isBold: Bool
            let isItalic: Bool
            let isUnderline: Bool
        }
        
        var chunks: [StyledChunk] = []
        var currentText = ""
        var isBold = false
        var isItalic = false
        var isUnderline = false
        
        var index = text.startIndex
        while index < text.endIndex {
            if text[index...].hasPrefix("<b>") || text[index...].hasPrefix("<strong>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if text[index...].hasPrefix("<b>") {
                    index = text.index(index, offsetBy: 3)
                } else {
                    index = text.index(index, offsetBy: 8)
                }
                isBold = true
            } else if text[index...].hasPrefix("</b>") || text[index...].hasPrefix("</strong>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if text[index...].hasPrefix("</b>") {
                    index = text.index(index, offsetBy: 4)
                } else {
                    index = text.index(index, offsetBy: 9)
                }
                isBold = false
            } else if text[index...].hasPrefix("<i>") || text[index...].hasPrefix("<em>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if text[index...].hasPrefix("<i>") {
                    index = text.index(index, offsetBy: 3)
                } else {
                    index = text.index(index, offsetBy: 4)
                }
                isItalic = true
            } else if text[index...].hasPrefix("</i>") || text[index...].hasPrefix("</em>") {
                let hasEmClose = text[index...].hasPrefix("</em>")
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if hasEmClose {
                    index = text.index(index, offsetBy: 5)
                } else {
                    index = text.index(index, offsetBy: 4) // </i>
                }
                isItalic = false
            } else if text[index...].hasPrefix("<u>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                index = text.index(index, offsetBy: 3)
                isUnderline = true
            } else if text[index...].hasPrefix("</u>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                index = text.index(index, offsetBy: 4)
                isUnderline = false
            } else {
                currentText.append(text[index])
                index = text.index(after: index)
            }
        }
        
        if !currentText.isEmpty {
            chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
        }
        
        let attributed = NSMutableAttributedString()
        for chunk in chunks {
            var font = defaultFont
            if chunk.isBold {
                font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            }
            if chunk.isItalic {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }
            
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: chunk.isBold ? boldColor : defaultColor
            ]
            
            if chunk.isUnderline {
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            
            attributed.append(NSAttributedString(string: chunk.text, attributes: attrs))
        }
        
        return attributed
    }
    

    
    private func getRatingButtons(for widget: TouchBarWidget, buttonCount: Int, intervals: [Int: Int] = [:], labels: [Int: String] = [:], showInterval: Bool = false) -> [(title: String, rating: Int, color: NSColor)] {
        var result: [(title: String, rating: Int, color: NSColor)] = []
        
        let againColor = NSColor(Color(hex: widget.ankiAgainColorHex))
        let hardColor = NSColor(Color(hex: widget.ankiHardColorHex))
        let goodColor = NSColor(Color(hex: widget.ankiGoodColorHex))
        let easyColor = NSColor(Color(hex: widget.ankiEasyColorHex))
        
        let intervalStr: (Int) -> String = { rating in
            guard showInterval else { return "" }
            if let label = labels[rating], !label.isEmpty {
                return " (\(label))"
            }
            return ""
        }
        
        if widget.ankiShowAgain {
            result.append((title: "Again" + intervalStr(1), rating: 1, color: againColor))
        }
        if widget.ankiShowHard && buttonCount >= 2 {
            result.append((title: "Hard" + intervalStr(2), rating: 2, color: hardColor))
        }
        if widget.ankiShowGood && buttonCount >= 2 {
            let ease = buttonCount == 2 ? 2 : 3
            result.append((title: "Good" + intervalStr(ease), rating: ease, color: goodColor))
        }
        if widget.ankiShowEasy {
            let ease: Int
            if buttonCount >= 4 {
                ease = 4
            } else if buttonCount >= 3 {
                ease = 3
            } else {
                ease = 2
            }
            result.append((title: "Easy" + intervalStr(ease), rating: ease, color: easyColor))
        }
        
        var seenRatings = Set<Int>()
        result = result.filter { seenRatings.insert($0.rating).inserted }
        
        return result
    }
    
    // MARK: - Native Volume & Brightness Factories
    
    private func makeNativeVolumeSlider(for widget: TouchBarWidget) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        
        let minImg = NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: "Mute")
        let minView = NSImageView(image: minImg ?? NSImage())
        minView.contentTintColor = NSColor(Color(hex: widget.textColorHex))
        minView.translatesAutoresizingMaskIntoConstraints = false
        minView.widthAnchor.constraint(equalToConstant: 14).isActive = true
        minView.heightAnchor.constraint(equalToConstant: 14).isActive = true
        
        let slider = NSSlider(
            value: getCurrentVolume(),
            minValue: 0,
            maxValue: 100,
            target: self,
            action: #selector(volumeSliderChanged(_:))
        )
        slider.controlSize = .small
        slider.wantsLayer = true
        slider.trackFillColor = NSColor(Color(hex: widget.backgroundColorHex))
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: CGFloat(widget.volumeSliderWidth)).isActive = true
        TouchBarPresenter.volumeSliders.add(slider)
        
        let maxImg = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: "Max Volume")
        let maxView = NSImageView(image: maxImg ?? NSImage())
        maxView.contentTintColor = NSColor(Color(hex: widget.textColorHex))
        maxView.translatesAutoresizingMaskIntoConstraints = false
        maxView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        maxView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        
        if widget.volumeShowIcon {
            stack.addArrangedSubview(minView)
        }
        stack.addArrangedSubview(slider)
        if widget.volumeShowIcon {
            stack.addArrangedSubview(maxView)
        }
        
        return stack
    }
    
    @objc private func volumeSliderChanged(_ sender: NSSlider) {
        let value = Int(sender.doubleValue)
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptString = "set volume output volume \(value)"
            if let script = NSAppleScript(source: scriptString) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
        }
    }
    
    private func getCurrentVolume() -> Double {
        Self.getCurrentVolumeValue()
    }
    
    nonisolated private static func getCurrentVolumeValue() -> Double {
        var error: NSDictionary?
        if let script = NSAppleScript(source: "output volume of (get volume settings)") {
            let descriptor = script.executeAndReturnError(&error)
            return Double(descriptor.int32Value)
        }
        return 50.0
    }
    
    nonisolated private static func setSystemVolume(_ value: Double) {
        let script = NSAppleScript(source: "set volume output volume \(Int(value))")
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
    }
    
    @objc static func refreshVolumeSliders() {
        DispatchQueue.global(qos: .background).async {
            let currentVolume = getCurrentVolumeValue()
            guard currentVolume != lastVolumeValue else { return }
            lastVolumeValue = currentVolume
            DispatchQueue.main.async {
                for slider in volumeSliders.allObjects {
                    slider.doubleValue = currentVolume
                }
            }
        }
    }
    
    private func makeNativeAnimationView(for widget: TouchBarWidget) -> NSView {
        let btn = NSButton(title: "", target: self, action: #selector(touchBarButtonTapped(_:)))
        btn.setButtonType(.momentaryPushIn)
        btn.isBordered = false
        btn.bezelStyle = .shadowlessSquare
        btn.setAccessibilityIdentifier(widget.id.uuidString)
        
        // Add long press gesture
        let longPress = NSPressGestureRecognizer(target: self, action: #selector(widgetLongPressed(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.allowedTouchTypes = .direct
        btn.addGestureRecognizer(longPress)
        
        let frames = touchbar.SystemUtils.extractGifFrames(from: widget.customGifPath)
        if !frames.isEmpty {
            btn.image = frames.first
            btn.imagePosition = .imageOnly
            
            var currentFrame = 0
            let timer = Timer.scheduledTimer(withTimeInterval: widget.animationSpeed, repeats: true) { _ in
                DispatchQueue.main.async {
                    currentFrame = (currentFrame + 1) % frames.count
                    btn.image = frames[currentFrame]
                }
            }
            objc_setAssociatedObject(btn, unsafeBitCast(timer, to: UnsafeRawPointer.self), timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 30).isActive = true
        } else {
            let presetFrames = widget.animationType.frames
            btn.font = NSFont.monospacedSystemFont(ofSize: CGFloat(widget.fontSize), weight: .medium)
            btn.contentTintColor = NSColor(Color(hex: widget.textColorHex))
            btn.imagePosition = .noImage
            
            if !presetFrames.isEmpty {
                var currentFrame = 0
                btn.title = presetFrames[0]
                let timer = Timer.scheduledTimer(withTimeInterval: widget.animationSpeed, repeats: true) { _ in
                    DispatchQueue.main.async {
                        currentFrame = (currentFrame + 1) % presetFrames.count
                        btn.title = presetFrames[currentFrame]
                    }
                }
                objc_setAssociatedObject(btn, unsafeBitCast(timer, to: UnsafeRawPointer.self), timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        return btn
    }
    
    // MARK: - NHK News View Factory
    
    private func makeNativeNHKNewsView(for widget: TouchBarWidget) -> NSView {
        guard let state = AppState.shared else {
            let label = NSTextField(labelWithString: "NHK News")
            label.font = NSFont.systemFont(ofSize: 12)
            return label
        }
        
        let nhk = state.nhkNewsState
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        // Custom width is handled by the caller in makeItemForIdentifier (see if widget.customWidth > 0.0)
        
        // News icon
        let iconView = NSImageView(image: NSImage(systemSymbolName: "", accessibilityDescription: "NHK News") ?? NSImage())
        iconView.contentTintColor = NSColor(Color(hex: widget.textColorHex))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        // iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        stack.addArrangedSubview(iconView)
        
        if nhk.isLoading {
            let label = NSTextField(labelWithString: "Loading...")
            label.font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize), weight: .medium)
            label.textColor = NSColor(Color(hex: widget.textColorHex))
            stack.addArrangedSubview(label)
            return stack
        }
        
        if !nhk.errorMessage.isEmpty {
            let label = NSTextField(labelWithString: "⚠️ \(String(nhk.errorMessage.prefix(25)))...")
            label.font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize) - 1)
            label.textColor = NSColor.orange
            stack.addArrangedSubview(label)
            
            let refreshBtn = NSButton(title: "Retry", target: self, action: #selector(nhkRefreshTapped(_:)))
            refreshBtn.bezelStyle = .rounded
            refreshBtn.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
            refreshBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex))
            refreshBtn.font = NSFont.systemFont(ofSize: 10)
            stack.addArrangedSubview(refreshBtn)
            return stack
        }
        
        if nhk.articles.isEmpty {
            let label = NSTextField(labelWithString: "📰 News")
            label.font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize), weight: .medium)
            label.textColor = NSColor(Color(hex: widget.textColorHex))
            stack.addArrangedSubview(label)
            
            let refreshBtn = NSButton(title: "Refresh", target: self, action: #selector(nhkRefreshTapped(_:)))
            refreshBtn.bezelStyle = .rounded
            refreshBtn.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
            refreshBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex))
            refreshBtn.font = NSFont.systemFont(ofSize: 10)
            stack.addArrangedSubview(refreshBtn)
            return stack
        }
        
        guard let article = nhk.currentArticle else {
            let label = NSTextField(labelWithString: "No articles")
            label.font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize))
            label.textColor = NSColor.gray
            stack.addArrangedSubview(label)
            return stack
        }
        
        switch nhk.mode {
        case .articleList:
            buildNHKArticleListView(nhk: nhk, article: article, stack: stack, widget: widget)
        case .reading:
            buildNHKReadingView(nhk: nhk, article: article, stack: stack, widget: widget)
        }
        
        return stack
    }
    
    private func buildNHKArticleListView(nhk: NHKNewsState, article: NHKNewsArticle, stack: NSStackView, widget: TouchBarWidget) {
        let titleContainer = NSView()
        titleContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let titleLabel = NSTextField(labelWithString: article.title)
        titleLabel.font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize), weight: .medium)
        titleLabel.textColor = NSColor(Color(hex: widget.textColorHex))
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false

        titleContainer.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor)
        ])

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let countLabel = NSTextField(labelWithString: "\(nhk.currentArticleIndex + 1)/\(nhk.articles.count)")
        countLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular)
        countLabel.textColor = NSColor(Color(hex: widget.textColorHex)).withAlphaComponent(0.6)
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let prevBtn = NSButton(title: "", target: self, action: #selector(nhkPrevTapped(_:)))
        if let prevImg = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Previous article") {
            prevBtn.image = prevImg
            prevBtn.imagePosition = .imageOnly
        } else {
            prevBtn.title = "◀"
        }
        prevBtn.bezelStyle = .rounded
        prevBtn.isBordered = false
        prevBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex)).withAlphaComponent(0.7)
        prevBtn.setContentCompressionResistancePriority(.required, for: .horizontal)

        let nextBtn = NSButton(title: "", target: self, action: #selector(nhkNextTapped(_:)))
        if let nextImg = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Next article") {
            nextBtn.image = nextImg
            nextBtn.imagePosition = .imageOnly
        } else {
            nextBtn.title = "▶"
        }
        nextBtn.bezelStyle = .rounded
        nextBtn.isBordered = false
        nextBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex)).withAlphaComponent(0.7)
        nextBtn.setContentCompressionResistancePriority(.required, for: .horizontal)

        if widget.nhkNavOnLeft {
            stack.addArrangedSubview(prevBtn)
            stack.addArrangedSubview(nextBtn)

            let readBtn = makeNHKReadButton(widget: widget)
            stack.addArrangedSubview(readBtn)

            stack.addArrangedSubview(countLabel)
            stack.addArrangedSubview(titleContainer)
            stack.addArrangedSubview(spacer)
        } else {
            stack.addArrangedSubview(titleContainer)
            stack.addArrangedSubview(spacer)
            stack.addArrangedSubview(countLabel)
            stack.addArrangedSubview(prevBtn)
            stack.addArrangedSubview(nextBtn)

            let readBtn = makeNHKReadButton(widget: widget)
            stack.addArrangedSubview(readBtn)
        }
    }

    private func makeNHKReadButton(widget: TouchBarWidget) -> NSButton {
        let readBtn = NSButton(title: "", target: self, action: #selector(nhkReadTapped(_:)))
        if let readImg = NSImage(systemSymbolName: "book.fill", accessibilityDescription: "Read article") {
            readBtn.image = readImg
            readBtn.imagePosition = .imageOnly
        } else {
            readBtn.title = "📖"
        }
        readBtn.bezelStyle = .rounded
        readBtn.isBordered = false
        readBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex))
        readBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
        return readBtn
    }
    
    private func buildNHKReadingView(nhk: NHKNewsState, article: NHKNewsArticle, stack: NSStackView, widget: TouchBarWidget) {
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.spacing = 4
        hStack.alignment = .centerY

        let kanjiSize = max(8, CGFloat(widget.fontSize - 2))
        let furiSize: CGFloat
        if widget.nhkFuriganaFontSize > 0 {
            furiSize = max(4, CGFloat(widget.nhkFuriganaFontSize))
        } else {
            furiSize = max(4, kanjiSize * 0.55)
        }

        let contentView: NSView
        if nhk.currentChunk.contains("[") && nhk.currentChunk.contains("]") {
            contentView = buildFuriganaRichLabel(
                text: nhk.currentChunk,
                fontSize: kanjiSize,
                textColor: NSColor(Color(hex: widget.textColorHex)),
                boldColor: NSColor(Color(hex: widget.ankiBoldColorHex)),
                isButton: false,
                manualFuriFontSize: furiSize,
                verticalOffset: 0,
                textVerticalOffset: 0,
                ankiTrimText: true,
                furiganaColor: NSColor(Color(hex: widget.nhkFuriganaColorHex)).withAlphaComponent(0.75)
            )
        } else {
            let contentLabel = NSTextField(labelWithString: nhk.currentChunk)
            contentLabel.font = NSFont.systemFont(ofSize: kanjiSize)
            contentLabel.textColor = NSColor(Color(hex: widget.textColorHex))
            contentLabel.lineBreakMode = .byTruncatingTail
            contentView = contentLabel
        }
        contentView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Wrap content in a container with click gesture for floating window
        let contentContainer = NSStackView(views: [contentView])
        contentContainer.orientation = .horizontal
        contentContainer.spacing = 0
        contentContainer.alignment = .centerY
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let contentClick = NSClickGestureRecognizer(target: self, action: #selector(nhkFloatingWindowTapped(_:)))
        contentClick.buttonMask = 1
        contentClick.allowedTouchTypes = .direct
        contentContainer.addGestureRecognizer(contentClick)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let chunkLabel: NSTextField?
        if nhk.hasChunks {
            let label = NSTextField(labelWithString: nhk.chunkProgress)
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 7, weight: .regular)
            label.textColor = NSColor(Color(hex: widget.textColorHex)).withAlphaComponent(0.5)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            chunkLabel = label
        } else {
            chunkLabel = nil
        }

        let playPauseBtn: NSButton?
        let stopBtn: NSButton?
        if nhk.isAudioAvailable {
            let ppBtn = NSButton(title: "", target: self, action: #selector(nhkPlayPauseTapped(_:)))
            let playSymbol = nhk.isAudioPlaying
                ? NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Pause")
                : NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")
            if let img = playSymbol {
                ppBtn.image = img
                ppBtn.imagePosition = .imageOnly
            } else {
                ppBtn.title = nhk.isAudioPlaying ? "⏸" : "▶"
            }
            ppBtn.bezelStyle = .rounded
            ppBtn.isBordered = false
            ppBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex)).withAlphaComponent(0.7)
            ppBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
            ppBtn.identifier = NSUserInterfaceItemIdentifier("nhkPlayPause")
            playPauseBtn = ppBtn

            let sBtn = NSButton(title: "", target: self, action: #selector(nhkStopTapped(_:)))
            if let img = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop") {
                sBtn.image = img
                sBtn.imagePosition = .imageOnly
            } else {
                sBtn.title = "⏹"
            }
            sBtn.bezelStyle = .rounded
            sBtn.isBordered = false
            sBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex)).withAlphaComponent(0.7)
            sBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
            stopBtn = sBtn
        } else {
            playPauseBtn = nil
            stopBtn = nil
        }

        let prevChunkBtn = NSButton(title: "", target: self, action: #selector(nhkPrevChunkTapped(_:)))
        if let img = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Previous chunk") {
            prevChunkBtn.image = img
            prevChunkBtn.imagePosition = .imageOnly
        } else {
            prevChunkBtn.title = "◀"
        }
        prevChunkBtn.bezelStyle = .rounded
        prevChunkBtn.isBordered = false
        prevChunkBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex)).withAlphaComponent(0.7)
        prevChunkBtn.setContentCompressionResistancePriority(.required, for: .horizontal)

        let nextChunkBtn = NSButton(title: "", target: self, action: #selector(nhkNextChunkTapped(_:)))
        if let img = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Next chunk") {
            nextChunkBtn.image = img
            nextChunkBtn.imagePosition = .imageOnly
        } else {
            nextChunkBtn.title = "▶"
        }
        nextChunkBtn.bezelStyle = .rounded
        nextChunkBtn.isBordered = false
        nextChunkBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex)).withAlphaComponent(0.7)
        nextChunkBtn.setContentCompressionResistancePriority(.required, for: .horizontal)

        let listBtn = NSButton(title: "", target: self, action: #selector(nhkListTapped(_:)))
        if let img = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Article list") {
            listBtn.image = img
            listBtn.imagePosition = .imageOnly
        } else {
            listBtn.title = "☰"
        }
        listBtn.bezelStyle = .rounded
        listBtn.isBordered = false
        listBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex)).withAlphaComponent(0.7)
        listBtn.setContentCompressionResistancePriority(.required, for: .horizontal)

        if widget.nhkNavOnLeft {
            hStack.addArrangedSubview(prevChunkBtn)
            hStack.addArrangedSubview(nextChunkBtn)
            hStack.addArrangedSubview(listBtn)
            if let pp = playPauseBtn { hStack.addArrangedSubview(pp) }
            if let sb = stopBtn { hStack.addArrangedSubview(sb) }
            if let cl = chunkLabel { hStack.addArrangedSubview(cl) }
            hStack.addArrangedSubview(contentContainer)
            hStack.addArrangedSubview(spacer)
        } else {
            hStack.addArrangedSubview(contentContainer)
            hStack.addArrangedSubview(spacer)
            if let cl = chunkLabel { hStack.addArrangedSubview(cl) }
            if let pp = playPauseBtn { hStack.addArrangedSubview(pp) }
            if let sb = stopBtn { hStack.addArrangedSubview(sb) }
            hStack.addArrangedSubview(prevChunkBtn)
            hStack.addArrangedSubview(nextChunkBtn)
            hStack.addArrangedSubview(listBtn)
        }

        stack.addArrangedSubview(hStack)
    }

    /// Compact furigana label that fits within Touch Bar height.
    /// Kanji text stays centered at the same baseline as plain text;
    /// furigana floats above the kanji without pushing it down.
    private func buildCompactFuriganaLabel(text: String, kanjiSize: CGFloat, furiSize: CGFloat, textColor: NSColor, boldColor: NSColor) -> NSView {
        let segments = touchbar.parseFuriganaSegments(text)
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.spacing = 0
        hStack.alignment = .centerY

        for segment in segments {
            if let furi = segment.furigana {
                // Container: kanji centered like plain text, furigana overlaid above
                let container = NSView()
                container.translatesAutoresizingMaskIntoConstraints = false

                let baseLabel = NSTextField(labelWithString: segment.text)
                baseLabel.font = NSFont.systemFont(ofSize: kanjiSize, weight: .regular)
                baseLabel.textColor = textColor
                baseLabel.isBezeled = false
                baseLabel.drawsBackground = false
                baseLabel.isEditable = false
                baseLabel.isSelectable = false
                baseLabel.cell?.usesSingleLineMode = true
                baseLabel.maximumNumberOfLines = 1
                baseLabel.cell?.wraps = false
                baseLabel.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(baseLabel)

                let furiLabel = NSTextField(labelWithString: furi)
                furiLabel.font = NSFont.systemFont(ofSize: furiSize, weight: .medium)
                furiLabel.textColor = textColor.withAlphaComponent(0.65)
                furiLabel.isBezeled = false
                furiLabel.drawsBackground = false
                furiLabel.isEditable = false
                furiLabel.isSelectable = false
                furiLabel.cell?.usesSingleLineMode = true
                furiLabel.maximumNumberOfLines = 1
                furiLabel.cell?.wraps = false
                furiLabel.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(furiLabel)

                NSLayoutConstraint.activate([
                    baseLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    baseLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    baseLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                    furiLabel.bottomAnchor.constraint(equalTo: baseLabel.topAnchor),
                    furiLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

                    container.topAnchor.constraint(lessThanOrEqualTo: furiLabel.topAnchor),
                    container.bottomAnchor.constraint(greaterThanOrEqualTo: baseLabel.bottomAnchor)
                ])

                hStack.addArrangedSubview(container)
            } else {
                let trimmed = segment.text.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                let label = NSTextField(labelWithString: trimmed)
                label.font = NSFont.systemFont(ofSize: kanjiSize, weight: .regular)
                label.textColor = textColor
                label.isBezeled = false
                label.drawsBackground = false
                label.isEditable = false
                label.isSelectable = false
                label.cell?.usesSingleLineMode = true
                label.maximumNumberOfLines = 1
                label.cell?.wraps = false
                hStack.addArrangedSubview(label)
            }
        }

        return hStack
    }
    
    // MARK: - NHK News Actions
    
    @objc private func nhkRefreshTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        Task { @MainActor in
            await state.nhkNewsState.fetchArticles()
        }
    }
    
    @objc private func nhkNextTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.nhkNewsState.nextArticle()
    }
    
    @objc private func nhkPrevTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.nhkNewsState.previousArticle()
    }
    
    @objc private func nhkPrevChunkTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.nhkNewsState.previousChunk()
    }

    @objc private func nhkReadTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.nhkNewsState.startReading()
    }

    @objc private func nhkNextChunkTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.nhkNewsState.nextChunk()
    }

    @objc private func nhkListTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.nhkNewsState.returnToList()
    }

    @objc private func nhkPlayPauseTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.nhkNewsState.playPauseAudio()
        TouchBarPresenter.refreshTouchBar()
    }

    @objc private func nhkStopTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.nhkNewsState.stopAudio()
        TouchBarPresenter.refreshTouchBar()
    }

    @objc private func nhkFloatingWindowTapped(_ sender: Any) {
        NHKFloatingWindowManager.shared.toggle()
    }

    
    private func makeNativeBrightnessControls(for widget: TouchBarWidget) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        
        let downBtn = NSButton(
            image: NSImage(systemSymbolName: "sun.min.fill", accessibilityDescription: "Brightness Down") ?? NSImage(),
            target: self,
            action: #selector(brightnessDownTapped(_:))
        )
        downBtn.bezelStyle = .rounded
        downBtn.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
        downBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex))
        
        let upBtn = NSButton(
            image: NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Brightness Up") ?? NSImage(),
            target: self,
            action: #selector(brightnessUpTapped(_:))
        )
        upBtn.bezelStyle = .rounded
        upBtn.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
        upBtn.contentTintColor = NSColor(Color(hex: widget.textColorHex))
        
        downBtn.translatesAutoresizingMaskIntoConstraints = false
        upBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            downBtn.widthAnchor.constraint(equalToConstant: CGFloat(widget.brightnessButtonSize)),
            upBtn.widthAnchor.constraint(equalToConstant: CGFloat(widget.brightnessButtonSize))
        ])
        
        stack.addArrangedSubview(downBtn)
        stack.addArrangedSubview(upBtn)
        
        return stack
    }
    
    @objc private func brightnessDownTapped(_ sender: NSButton) {
        adjustBrightness(up: false)
    }
    
    @objc private func brightnessUpTapped(_ sender: NSButton) {
        adjustBrightness(up: true)
    }
    
    private func adjustBrightness(up: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            touchbar.SystemUtils.adjustBrightness(up: up)
        }
    }
}

// MARK: - Dock Widget View

private class DockWidgetView: NSView {
    private let stack: NSStackView = {
        let s = NSStackView()
        s.orientation = .horizontal
        s.spacing = 4
        s.alignment = .centerY
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let widget: TouchBarWidget
    private unowned let target: AnyObject
    private let action: Selector

    init(widget: TouchBarWidget, target: AnyObject, action: Selector) {
        self.widget = widget
        self.target = target
        self.action = action
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        if widget.customWidth > 0 {
            let scrollView = NSScrollView()
            scrollView.hasHorizontalScroller = false
            scrollView.hasVerticalScroller = false
            scrollView.borderType = .noBorder
            scrollView.drawsBackground = false
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(scrollView)
            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                scrollView.topAnchor.constraint(equalTo: topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            scrollView.documentView = stack
            stack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor).isActive = true
            stack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor).isActive = true
            stack.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor).isActive = true
        } else {
            addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: leadingAnchor),
                stack.topAnchor.constraint(equalTo: topAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }

        reload()
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
    }

    required init?(coder: NSCoder) { nil }

    private func reload() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        if runningApps.isEmpty {
            let label = NSTextField(labelWithString: "No Apps")
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = NSColor.gray
            stack.addArrangedSubview(label)
            return
        }
        for app in runningApps {
            guard let icon = app.icon else { continue }
            let btn = NSButton(image: icon, target: target, action: action)
            btn.bezelStyle = .rounded
            btn.isBordered = false
            btn.imagePosition = .imageOnly
            btn.setAccessibilityLabel(app.localizedName ?? "App")
            btn.setAccessibilityIdentifier(app.bundleIdentifier ?? "")
            btn.widthAnchor.constraint(equalToConstant: 28).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 28).isActive = true
            btn.imageScaling = .scaleProportionallyDown
            stack.addArrangedSubview(btn)
        }
    }
}

// MARK: - Dock View Factory

extension TouchBarPresenter {
    private func makeNativeDockView(for widget: TouchBarWidget) -> NSView {
        return DockWidgetView(widget: widget, target: self, action: #selector(dockAppTapped(_:)))
    }

    @objc private func dockAppTapped(_ sender: NSButton) {
        let bundleID = sender.accessibilityIdentifier()
        guard !bundleID.isEmpty else { return }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }
}

// MARK: - App Launcher View Factory

extension TouchBarPresenter {
    private func makeNativeAppLauncherView(for widget: TouchBarWidget) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false

        if !widget.appLauncherApps.isEmpty {
            for bundleID in widget.appLauncherApps {
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { continue }
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                let btn = NSButton(image: icon, target: self, action: #selector(appLauncherTapped(_:)))
                btn.bezelStyle = .rounded
                btn.isBordered = false
                btn.imagePosition = .imageOnly
                btn.setAccessibilityLabel(bundleID)
                btn.setAccessibilityIdentifier(bundleID)
                btn.widthAnchor.constraint(equalToConstant: 28).isActive = true
                btn.heightAnchor.constraint(equalToConstant: 28).isActive = true
                btn.imageScaling = .scaleProportionallyDown
                stack.addArrangedSubview(btn)
            }
        } else {
            let label = NSTextField(labelWithString: "No Apps")
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = NSColor.gray
            stack.addArrangedSubview(label)
        }

        if widget.customWidth > 0 {
            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            let scrollView = NSScrollView()
            scrollView.hasHorizontalScroller = false
            scrollView.hasVerticalScroller = false
            scrollView.borderType = .noBorder
            scrollView.drawsBackground = false
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(scrollView)
            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                scrollView.topAnchor.constraint(equalTo: container.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
            scrollView.documentView = stack
            stack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor).isActive = true
            stack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor).isActive = true
            stack.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor).isActive = true
            return container
        }

        return stack
    }

    @objc private func appLauncherTapped(_ sender: NSButton) {
        let bundleID = sender.accessibilityIdentifier()
        guard !bundleID.isEmpty else { return }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }
}

class TouchBarContainerButton: NSButton {
    private var hostView: NSView?
    
    init(hostView: NSView, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.hostView = hostView
        self.target = target
        self.action = action
        self.isBordered = false
        self.bezelStyle = .shadowlessSquare
        self.title = ""
        self.image = nil
        
        addSubview(hostView)
        hostView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostView.topAnchor.constraint(equalTo: topAnchor),
            hostView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
