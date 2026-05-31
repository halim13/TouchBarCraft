import AppKit
import SwiftUI

@MainActor
public final class StatusItemManager: NSObject {
    public static let shared = StatusItemManager()
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var muteMenuItem: NSMenuItem?
    
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
    
    private func constructMenu() {
        let menu = NSMenu()
        let isMuted = AppState.shared?.ankiState.isMuted ?? false
        
        let settingsItem = NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let toggleLayoutItem = NSMenuItem(title: "Toggle Anki Touch Bar Layout", action: #selector(toggleAnkiLayout), keyEquivalent: "t")
        toggleLayoutItem.target = self
        toggleLayoutItem.keyEquivalentModifierMask = [.command]
        menu.addItem(toggleLayoutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Mute toggle
        let muteItem = NSMenuItem(
            title: isMuted ? "Unmute Anki Audio" : "Mute Anki Audio",
            action: #selector(toggleMute),
            keyEquivalent: "m"
        )
        muteItem.target = self
        muteItem.keyEquivalentModifierMask = [.command]
        if isMuted {
            muteItem.state = .on
        }
        menu.addItem(muteItem)
        self.muteMenuItem = muteItem
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
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
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
