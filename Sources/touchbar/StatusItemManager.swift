import AppKit
import SwiftUI

@MainActor
public final class StatusItemManager: NSObject {
    public static let shared = StatusItemManager()
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var muteMenuItem: NSMenuItem?
    private var furiganaMenuItem: NSMenuItem?
    private var ankiQuestionMenuItem: NSMenuItem?
    private var ankiAnswerMenuItem: NSMenuItem?
    private var ankiDeckMenuItem: NSMenuItem?
    private var hotkeyHeaderMenuItem: NSMenuItem?
    private var gameControllerMenuItem: NSMenuItem?
    private var floatingOverlayMenuItem: NSMenuItem?
    
    private override init() {
        super.init()
    }
    
    public func setupStatusItem() {
        // Create Status Item on system menu bar (right side)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateStatusItemIcon()
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }
        
        constructMenu()
    }
    
    private func updateStatusItemIcon() {
        guard let button = statusItem?.button else { return }
        let isMuted = AppState.shared?.ankiState.isMuted ?? false
        
        if isMuted {
            if let image = NSImage(systemSymbolName: "speaker.slash", accessibilityDescription: "TouchBarCraft - Muted") {
                button.image = image
            } else {
                button.title = "🔇"
            }
        } else {
            if let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "TouchBarCraft") {
                button.image = image
            } else {
                button.title = "⌨️"
            }
        }
    }
    
    public func rebuildMenu() {
        constructMenu()
    }

    private func constructMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let state = AppState.shared
        let ankiVisible = state?.widgets.contains { $0.type == .anki && !$0.isHidden } ?? false
        let nhkVisible = state?.widgets.contains { $0.type == .nhkNews && !$0.isHidden } ?? false

        if ankiVisible {
            let ankiMenu = NSMenu()
            ankiMenu.autoenablesItems = false

            let isMuted = state?.ankiState.isMuted ?? false

            let toggleLayoutItem = NSMenuItem(title: "Toggle Layout", action: #selector(toggleAnkiLayout), keyEquivalent: "t")
            toggleLayoutItem.target = self
            toggleLayoutItem.keyEquivalentModifierMask = [.command]
            ankiMenu.addItem(toggleLayoutItem)

            let muteItem = NSMenuItem(
                title: isMuted ? "Unmute Audio" : "Mute Audio",
                action: #selector(toggleMute),
                keyEquivalent: "m"
            )
            muteItem.target = self
            muteItem.keyEquivalentModifierMask = [.command]
            if isMuted { muteItem.state = .on }
            ankiMenu.addItem(muteItem)
            self.muteMenuItem = muteItem

            let furiganaOn = isFuriganaEnabled()
            let furiganaItem = NSMenuItem(
                title: furiganaOn ? "Hide Furigana" : "Show Furigana",
                action: #selector(toggleFurigana),
                keyEquivalent: "f"
            )
            furiganaItem.target = self
            furiganaItem.keyEquivalentModifierMask = [.command]
            if furiganaOn { furiganaItem.state = .on }
            ankiMenu.addItem(furiganaItem)
            self.furiganaMenuItem = furiganaItem

            let overlayEnabled = AnkiFloatingOverlayManager.shared.config.isEnabled
            let overlayShowing = AnkiFloatingOverlayManager.shared.isShowing
            let overlayItem = NSMenuItem(
                title: overlayShowing ? "Hide Floating Overlay" : "Show Floating Overlay",
                action: #selector(toggleFloatingOverlay),
                keyEquivalent: "o"
            )
            overlayItem.target = self
            overlayItem.keyEquivalentModifierMask = [.command]
            overlayItem.isEnabled = overlayEnabled
            if overlayShowing { overlayItem.state = .on }
            ankiMenu.addItem(overlayItem)
            self.floatingOverlayMenuItem = overlayItem

            ankiMenu.addItem(NSMenuItem.separator())

            let hkHeader = NSMenuItem(title: "Global Shortcuts", action: nil, keyEquivalent: "")
            hkHeader.isEnabled = false
            hkHeader.attributedTitle = NSAttributedString(
                string: "Global Shortcuts",
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: NSColor.systemPurple
                ]
            )
            ankiMenu.addItem(hkHeader)
            self.hotkeyHeaderMenuItem = hkHeader

            buildGlobalShortcutItems(menu: ankiMenu)

            let gcItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            gcItem.isEnabled = false
            updateGameControllerMenuItem(gcItem)
            ankiMenu.addItem(gcItem)
            self.gameControllerMenuItem = gcItem

            let ankiMenuItem = NSMenuItem(title: "Anki", action: nil, keyEquivalent: "")
            ankiMenuItem.submenu = ankiMenu
            menu.addItem(ankiMenuItem)
        }

        if nhkVisible {
            let nhkMenu = NSMenu()
            nhkMenu.autoenablesItems = false

            let nhkState = state?.nhkNewsState
            let articleCount = nhkState?.articles.count ?? 0
            let statusText: String
            if nhkState?.isLoading ?? false {
                statusText = "Loading..."
            } else if articleCount > 0 {
                statusText = "\(articleCount) articles loaded"
            } else {
                statusText = "No articles"
            }

            let statusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            statusItem.attributedTitle = NSAttributedString(
                string: statusText,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: articleCount > 0 ? NSColor.green : NSColor.gray
                ]
            )
            nhkMenu.addItem(statusItem)

            let refreshItem = NSMenuItem(title: "Refresh News", action: #selector(nhkRefreshFromMenu), keyEquivalent: "r")
            refreshItem.target = self
            refreshItem.keyEquivalentModifierMask = [.command, .shift]
            nhkMenu.addItem(refreshItem)

            if nhkState?.mode == .reading {
                let returnItem = NSMenuItem(title: "Return to List", action: #selector(nhkReturnToListFromMenu), keyEquivalent: "l")
                returnItem.target = self
                returnItem.keyEquivalentModifierMask = [.command, .shift]
                nhkMenu.addItem(returnItem)
            }

            let nhkMenuItem = NSMenuItem(title: "NHK Easy News", action: nil, keyEquivalent: "")
            nhkMenuItem.submenu = nhkMenu
            menu.addItem(nhkMenuItem)
        }

        let quitSeparator = NSMenuItem.separator()
        menu.addItem(quitSeparator)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu

        refreshAnkiCardInfo()
    }
    
    /// Update the mute menu item and tray icon without fully reconstructing the menu.
    /// Call this after toggling mute from anywhere (settings panel, tray, etc.)
    /// so the tray indicator stays in sync.
    public func refreshMuteState() {
        let isMuted = AppState.shared?.ankiState.isMuted ?? false
        muteMenuItem?.title = isMuted ? "Unmute Anki Audio" : "Mute Anki Audio"
        muteMenuItem?.state = isMuted ? .on : .off
        updateStatusItemIcon()
    }
    
    @objc private func statusItemClicked(_ sender: Any?) {
        // Menu is displayed automatically when clicked
    }
    
    @objc public func openSettings() {
        if settingsWindow == nil {
            // Find existing or create new state
            let appState = AppState.shared ?? AppState()
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 950, height: 650),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            window.title = "TouchBarCraft Settings"
            window.titlebarAppearsTransparent = false
            window.center()
            window.isReleasedWhenClosed = false
            
            let hostView = NSHostingView(rootView: MainView(state: appState))
            window.contentView = hostView
            
            self.settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func toggleAnkiLayout() {
        TouchBarPresenter.shared.toggleLayout()
    }
    
    @objc private func toggleMute() {
        guard let state = AppState.shared else { return }
        state.ankiState.toggleMute()
        state.saveConfig()
        refreshMuteState()
    }
    
    @objc private func toggleFurigana() {
        guard let state = AppState.shared else { return }
        guard let ankiIndex = state.widgets.firstIndex(where: { $0.type == .anki }) else { return }
        
        state.widgets[ankiIndex].ankiCombineFurigana.toggle()
        state.saveConfig()
        refreshFuriganaState()
        refreshAnkiCardInfo()
    }
    
    private func isFuriganaEnabled() -> Bool {
        guard let state = AppState.shared else { return false }
        return state.widgets.first(where: { $0.type == .anki })?.ankiCombineFurigana ?? false
    }
    
    /// Build menu items for active global shortcuts and add them to the menu.
    /// Items are inserted right after the header item.
    private func buildGlobalShortcutItems(menu: NSMenu) {
        guard let headerItem = hotkeyHeaderMenuItem else { return }
        
        let bindings = GlobalHotkeyManager.shared.allBindings
        let activeBindings = bindings.filter { $0.binding.isEnabled && $0.binding.isValid }
        let headerIndex = menu.index(of: headerItem)
        
        if activeBindings.isEmpty {
            let emptyItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            emptyItem.attributedTitle = NSAttributedString(
                string: "No shortcuts set",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.gray
                ]
            )
            menu.insertItem(emptyItem, at: headerIndex + 1)
        } else {
            var insertIndex = headerIndex + 1
            for (action, binding) in activeBindings {
                let item = NSMenuItem(
                    title: "\(action.displayName): \(binding.displayString)",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                item.attributedTitle = NSAttributedString(
                    string: "\(action.displayName): \(binding.displayString)",
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                        .foregroundColor: NSColor.white
                    ]
                )
                item.toolTip = "Global shortcut for \(action.displayName)"
                menu.insertItem(item, at: insertIndex)
                insertIndex += 1
            }
        }
    }
    
    /// Clean and rebuild the global shortcut items in the menu.
    /// Call this whenever a hotkey binding changes (add, remove, toggle, update) so the menu stays in sync.
    public func refreshGlobalShortcuts() {
        guard let headerItem = hotkeyHeaderMenuItem, let menu = headerItem.menu else { return }

        // Remove all items after header up to gameControllerMenuItem
        let headerIndex = menu.index(of: headerItem)
        while let item = menu.item(at: headerIndex + 1), item !== gameControllerMenuItem {
            menu.removeItem(at: headerIndex + 1)
        }

        // Rebuild
        let bindings = GlobalHotkeyManager.shared.allBindings
        let activeBindings = bindings.filter { $0.binding.isEnabled && $0.binding.isValid }

        if activeBindings.isEmpty {
            let emptyItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            emptyItem.attributedTitle = NSAttributedString(
                string: "No shortcuts set",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.gray
                ]
            )
            menu.insertItem(emptyItem, at: headerIndex + 1)
        } else {
            var insertIndex = headerIndex + 1
            for (action, binding) in activeBindings {
                let item = NSMenuItem(
                    title: "\(action.displayName): \(binding.displayString)",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                item.attributedTitle = NSAttributedString(
                    string: "\(action.displayName): \(binding.displayString)",
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                        .foregroundColor: NSColor.white
                    ]
                )
                item.toolTip = "Global shortcut for \(action.displayName)"
                menu.insertItem(item, at: insertIndex)
                insertIndex += 1
            }
        }
    }
    
    /// Update a game controller menu item with current status.
    private func updateGameControllerMenuItem(_ item: NSMenuItem) {
        let gm = GameControllerManager.shared
        if gm.isEnabled && !gm.isGamingMode {
            let status: String
            if gm.hasConnectedController {
                status = "✅ Gamepad: \(gm.connectedControllers.joined(separator: ", "))"
            } else {
                status = "🎮 No controller connected"
            }
            item.attributedTitle = NSAttributedString(
                string: status,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: gm.hasConnectedController ? NSColor.green : NSColor.gray
                ]
            )
        } else if gm.isGamingMode {
            item.attributedTitle = NSAttributedString(
                string: "🎮 Gaming mode — Anki controller disabled",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.orange
                ]
            )
        } else {
            item.attributedTitle = NSAttributedString(
                string: "🎮 Controller support disabled",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.gray
                ]
            )
        }
    }
    
    /// Refresh game controller status in the menu bar.
    public func refreshGameControllerStatus() {
        guard let item = gameControllerMenuItem else { return }
        updateGameControllerMenuItem(item)
    }
    
    @objc private func toggleFloatingOverlay() {
        AnkiFloatingOverlayManager.shared.toggle()
    }

    @objc private func nhkRefreshFromMenu() {
        Task { @MainActor in
            await AppState.shared?.nhkNewsState.fetchArticles()
        }
    }

    @objc private func nhkReturnToListFromMenu() {
        AppState.shared?.nhkNewsState.returnToList()
    }

    public func refreshFloatingOverlayState() {
        let enabled = AnkiFloatingOverlayManager.shared.config.isEnabled
        let showing = AnkiFloatingOverlayManager.shared.isShowing
        floatingOverlayMenuItem?.title = showing ? "Hide Floating Overlay" : "Show Floating Overlay"
        floatingOverlayMenuItem?.state = showing ? .on : .off
        floatingOverlayMenuItem?.isEnabled = enabled
    }
    
    /// Update the furigana menu item title and state.
    /// Call this after toggling furigana from anywhere (settings panel, tray, etc.)
    public func refreshFuriganaState() {
        let enabled = isFuriganaEnabled()
        furiganaMenuItem?.title = enabled ? "Hide Furigana" : "Show Furigana"
        furiganaMenuItem?.state = enabled ? .on : .off
        // Also refresh card info display in tray
        refreshAnkiCardInfo()
    }
    
    /// Update the Anki card info menu items with current card data (includes furigana).
    /// Call this whenever the card changes (load, reveal, rate).
    public func refreshAnkiCardInfo() {
        guard let state = AppState.shared else { return }
        let anki = state.ankiState
        
        if let card = anki.currentCard {
            // Get the active widget for furigana settings
            let widget = state.widgets.first(where: { $0.type == .anki })
            let combineFurigana = widget?.ankiCombineFurigana ?? false
            
            // Deck name
            ankiDeckMenuItem?.title = "Deck: \(card.deckName)"
            ankiDeckMenuItem?.isEnabled = true
            
            // Question — strip HTML always; keep furigana [reading] brackets if enabled
            let qStripped = stripHTML(card.question)
            let qDisplay: String
            if combineFurigana {
                qDisplay = "Q: \(qStripped)"
            } else {
                let noFuri = stripFurigana(qStripped)
                qDisplay = "Q: \(noFuri)"
            }
            ankiQuestionMenuItem?.title = combineFurigana ? qDisplay : truncateMenuText(qDisplay, maxLen: 60)
            ankiQuestionMenuItem?.isEnabled = true
            ankiQuestionMenuItem?.toolTip = qDisplay
            
            // Answer — strip HTML always; keep furigana [reading] brackets if enabled
            if anki.isShowingAnswer {
                let aStripped = stripHTML(card.answer)
                let aDisplay: String
                if combineFurigana {
                    aDisplay = "A: \(aStripped)"
                } else {
                    let noFuri = stripFurigana(aStripped)
                    aDisplay = "A: \(noFuri)"
                }
                ankiAnswerMenuItem?.title = combineFurigana ? aDisplay : truncateMenuText(aDisplay, maxLen: 60)
                ankiAnswerMenuItem?.isEnabled = true
                ankiAnswerMenuItem?.toolTip = aDisplay
            } else {
                ankiAnswerMenuItem?.title = "Answer: (reveal first)"
                ankiAnswerMenuItem?.isEnabled = false
                ankiAnswerMenuItem?.toolTip = nil
            }
        } else {
            ankiDeckMenuItem?.title = anki.isConnected ? "No card loaded" : "Anki disconnected"
            ankiDeckMenuItem?.isEnabled = false
            ankiQuestionMenuItem?.title = "Question: —"
            ankiQuestionMenuItem?.isEnabled = false
            ankiQuestionMenuItem?.toolTip = nil
            ankiAnswerMenuItem?.title = "Answer: —"
            ankiAnswerMenuItem?.isEnabled = false
            ankiAnswerMenuItem?.toolTip = nil
        }
    }
    
    /// Truncate text for menu display with ellipsis
    private func truncateMenuText(_ text: String, maxLen: Int) -> String {
        if text.count <= maxLen { return text }
        return String(text.prefix(maxLen - 1)) + "…"
    }
    
    /// Strip HTML tags, keeping furigana [reading] brackets intact
    private func stripHTML(_ text: String) -> String {
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
    
    /// Strip furigana [reading] brackets and their content
    private func stripFurigana(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\\[[^\\]]+\\]", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
