import SwiftUI
import AppKit

import SwiftUI
import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate, Sendable {
    @MainActor private static var appState: AppState?

    @MainActor
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an accessory application (no Dock icon, resides in background/menu bar)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize AppState so default config loads and system monitors run immediately
        let state = AppState()
        Self.appState = state
        
        // Request Accessibility permission so we can simulate key events (System Events / keystroke / key code)
        let options = ["AXTrustedCheckOptionPrompt" as String: kCFBooleanTrue as Any] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        
        // Setup Control Strip and trigger global Touch Bar system-wide override
        TouchBarPresenter.shared.setupSystemTrayItem()
        TouchBarPresenter.shared.presentGlobalTouchBar()
        
        // Setup the Menu Bar status item
        StatusItemManager.shared.setupStatusItem()
        
        // Initialize global keyboard shortcuts for Anki actions
        GlobalHotkeyManager.shared.setup()
    }
    
    @MainActor
    public func applicationWillTerminate(_ notification: Notification) {
        // Clean up tray item and dismiss system modal override cleanly on exit
        TouchBarPresenter.shared.dismissGlobalTouchBar()
        TouchBarPresenter.shared.removeSystemTrayItem()
        GlobalHotkeyManager.shared.tearDown()
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

@main
struct TouchBarCraftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
