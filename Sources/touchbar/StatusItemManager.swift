import AppKit
import SwiftUI

@MainActor
public final class StatusItemManager: NSObject {
    public static let shared = StatusItemManager()
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func setupStatusItem() {
        // Create Status Item on system menu bar (right side)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use a SF Symbol image
            if let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "TouchBarCraft") {
                button.image = image
            } else {
                button.title = "⌨️"
            }
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }
        
        constructMenu()
    }
    
    private func constructMenu() {
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let toggleLayoutItem = NSMenuItem(title: "Toggle Anki Touch Bar Layout", action: #selector(toggleAnkiLayout), keyEquivalent: "t")
        toggleLayoutItem.target = self
        toggleLayoutItem.keyEquivalentModifierMask = [.command]
        menu.addItem(toggleLayoutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
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
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
