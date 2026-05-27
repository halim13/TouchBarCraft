import AppKit
import SwiftUI
import Foundation

@objc protocol NSTouchBarPrivate {
    static func presentSystemModalTouchBar(_ touchBar: NSTouchBar, placement: Int64, systemTrayItemIdentifier: String)
    static func presentSystemModalTouchBar(_ touchBar: NSTouchBar, systemTrayItemIdentifier: String)
    static func dismissSystemModalTouchBar(_ touchBar: NSTouchBar)
    static func minimizeSystemModalTouchBar(_ touchBar: NSTouchBar)
}

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
        setupWorkspaceNotifications()
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
            touchBar.defaultItemIdentifiers = state.widgets.map { NSTouchBarItem.Identifier($0.id.uuidString) }
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
        DispatchQueue.main.async {
            let presenter = TouchBarPresenter.shared
            if presenter.globalTouchBar != nil {
                presenter.presentGlobalTouchBar()
            }
            // Pastikan tombol close tetap tersembunyi
            presenter.dfrSystemModalShowsCloseBoxWhenFrontMost?(false)
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
    
    @objc private func ankiSyncTapped(_ sender: NSButton) {
        guard let state = AppState.shared else { return }
        state.ankiState.syncDecks()
    }
    
    @objc private func ankiAudioToggleTapped(_ sender: Any) {
        guard let state = AppState.shared else { return }
        state.ankiState.toggleAudio()
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
        }
        
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
        stack.widthAnchor.constraint(equalToConstant: CGFloat(widget.ankiTextMaxWidth + 160)).isActive = true

        
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
        
        // Add Sync Button (selalu tampil) dan progress spinner di sebelahnya jika sedang syncing
        let syncButton = NSButton(title: "", target: self, action: #selector(ankiSyncTapped(_:)))
        syncButton.bezelStyle = .rounded
        syncButton.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
        syncButton.contentTintColor = NSColor(Color(hex: widget.textColorHex))
        
        if let syncImage = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Sync") {
            syncButton.image = syncImage
            syncButton.imagePosition = .imageOnly
        } else {
            syncButton.title = "Sync"
        }
        
        syncButton.translatesAutoresizingMaskIntoConstraints = false
        syncButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        
        if anki.isSyncing {
            syncButton.isEnabled = false
            stack.addArrangedSubview(syncButton)
        } else {
            syncButton.isEnabled = true
            stack.addArrangedSubview(syncButton)
        }
        
        guard let card = anki.currentCard else {
            let label = NSTextField(labelWithString: "Anki: Select Deck")
            label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = NSColor(Color(hex: widget.textColorHex))
            
            stack.addArrangedSubview(label)
            return stack
        }
        
        if !anki.isShowingAnswer {
            let label = NSTextField(labelWithString: "")
            let font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize), weight: .medium)
            let textColor = NSColor(Color(hex: widget.textColorHex))
            let boldColor = NSColor(Color(hex: widget.ankiBoldColorHex))
            
            let prefix = NSMutableAttributedString(string: "", attributes: [.font: font, .foregroundColor: textColor])
            let content = parseBoldTags(in: card.question, defaultFont: font, defaultColor: textColor, boldColor: boldColor)
            prefix.append(content)
            
            label.attributedStringValue = prefix
            label.lineBreakMode = .byTruncatingTail
            label.cell?.truncatesLastVisibleLine = true
            
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)

            
            let btn = NSButton(title: "Reveal ▶", target: self, action: #selector(ankiRevealTapped(_:)))
            btn.bezelStyle = .rounded
            btn.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
            btn.contentTintColor = NSColor(Color(hex: widget.textColorHex))
            btn.font = NSFont.systemFont(ofSize: CGFloat(max(9, widget.fontSize - 1)), weight: .semibold)
            // Button must never shrink
            btn.setContentCompressionResistancePriority(.required, for: .horizontal)
            btn.setContentHuggingPriority(.required, for: .horizontal)
            
            stack.addArrangedSubview(label)
            stack.addArrangedSubview(btn)
        } else {
            let label = NSTextField(labelWithString: "")
            let font = NSFont.systemFont(ofSize: CGFloat(widget.fontSize), weight: .medium)
            let textColor = NSColor(Color(hex: widget.textColorHex))
            let boldColor = NSColor(Color(hex: widget.ankiBoldColorHex))
            
            let prefix = NSMutableAttributedString(string: "", attributes: [.font: font, .foregroundColor: textColor])
            let content = parseBoldTags(in: card.answer, defaultFont: font, defaultColor: textColor, boldColor: boldColor)
            prefix.append(content)
            
            label.attributedStringValue = prefix
            label.lineBreakMode = .byTruncatingTail
            label.cell?.truncatesLastVisibleLine = true
            
            let gesture = NSClickGestureRecognizer(target: self, action: #selector(ankiAudioToggleTapped(_:)))
            label.addGestureRecognizer(gesture)
            
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            stack.addArrangedSubview(label)
            
            let count = card.buttonCount
            let buttonsToShow = getRatingButtons(for: widget, buttonCount: count)
            
            for btnSpec in buttonsToShow {
                let btn = NSButton(title: btnSpec.title, target: self, action: #selector(ankiRatingTapped(_:)))
                btn.tag = btnSpec.rating
                btn.bezelStyle = .rounded
                btn.bezelColor = btnSpec.color
                btn.contentTintColor = .white
                // Fixed font size 11 for ratings as requested
                btn.font = NSFont.systemFont(ofSize: 11, weight: .bold)
                btn.setContentCompressionResistancePriority(.required, for: .horizontal)
                btn.setContentHuggingPriority(.required, for: .horizontal)
                stack.addArrangedSubview(btn)
            }
            
            // Add custom play/stop audio button on the right
            if card.soundFilename != nil {
                let audioBtn = NSButton(title: "", target: self, action: #selector(ankiAudioToggleTapped(_:)))
                audioBtn.bezelStyle = .rounded
                audioBtn.bezelColor = NSColor(Color(hex: widget.backgroundColorHex))
                let symbolName = anki.isAudioPlaying ? "stop.fill" : "play.fill"
                if let audioImg = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Toggle Audio") {
                    audioBtn.image = audioImg
                    audioBtn.imagePosition = .imageOnly
                } else {
                    audioBtn.title = anki.isAudioPlaying ? "Stop" : "Play"
                }
                audioBtn.translatesAutoresizingMaskIntoConstraints = false
                audioBtn.widthAnchor.constraint(equalToConstant: 30).isActive = true
                audioBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
                audioBtn.setContentHuggingPriority(.required, for: .horizontal)
                stack.addArrangedSubview(audioBtn)
            }
        }
        
        return stack
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
    
    private func getRatingButtons(for widget: TouchBarWidget, buttonCount: Int) -> [(title: String, rating: Int, color: NSColor)] {
        var result: [(title: String, rating: Int, color: NSColor)] = []
        
        let redColor = NSColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
        let orangeColor = NSColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1.0)
        let greenColor = NSColor(red: 0.1, green: 0.7, blue: 0.3, alpha: 1.0)
        let blueColor = NSColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
        
        // Anki ease ratings: 1=Again, 2=Hard, 3=Good, 4=Easy
        if buttonCount == 2 {
            if widget.ankiShowAgain {
                result.append((title: "Again", rating: 1, color: redColor))
            }
            if widget.ankiShowGood {
                result.append((title: "Good", rating: 3, color: greenColor))
            }
        } else if buttonCount == 3 {
            if widget.ankiShowAgain {
                result.append((title: "Again", rating: 1, color: redColor))
            }
            if widget.ankiShowGood {
                result.append((title: "Good", rating: 3, color: greenColor))
            }
            if widget.ankiShowEasy {
                result.append((title: "Easy", rating: 4, color: blueColor))
            }
        } else {
            if widget.ankiShowAgain {
                result.append((title: "Again", rating: 1, color: redColor))
            }
            if widget.ankiShowHard {
                result.append((title: "Hard", rating: 2, color: orangeColor))
            }
            if widget.ankiShowGood {
                result.append((title: "Good", rating: 3, color: greenColor))
            }
            if widget.ankiShowEasy {
                result.append((title: "Easy", rating: 4, color: blueColor))
            }
        }
        
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
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: CGFloat(widget.volumeSliderWidth)).isActive = true
        
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
        var error: NSDictionary?
        if let script = NSAppleScript(source: "output volume of (get volume settings)") {
            let descriptor = script.executeAndReturnError(&error)
            return Double(descriptor.int32Value)
        }
        return 50.0
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

