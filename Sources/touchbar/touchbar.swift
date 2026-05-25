import SwiftUI
import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate, Sendable {
    @MainActor
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Force the app to act as a regular foreground application with active Dock Icon and Menu Bar
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Setup Control Strip and trigger global Touch Bar system-wide override
        TouchBarPresenter.shared.setupSystemTrayItem()
        TouchBarPresenter.shared.presentGlobalTouchBar()
    }
    
    @MainActor
    public func applicationWillTerminate(_ notification: Notification) {
        // Clean up tray item and dismiss system modal override cleanly on exit
        TouchBarPresenter.shared.dismissGlobalTouchBar()
        TouchBarPresenter.shared.removeSystemTrayItem()
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct TouchBarCraftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var state = AppState()
    
    var body: some Scene {
        Window("TouchBarCraft", id: "main") {
            MainView(state: state)
                .touchBar {
                    ForEach(state.widgets) { widget in
                        Group {
                            switch widget.type {
                            case .label:
                                WidgetLabelView(widget: widget, state: state, isSimulator: false)
                            case .button:
                                WidgetButtonView(widget: widget, state: state, isSimulator: false)
                            case .systemMonitor:
                                WidgetSystemMonitorView(widget: widget, state: state, isSimulator: false)
                            case .media:
                                WidgetMediaView(widget: widget, state: state, isSimulator: false)
                            case .animation:
                                WidgetAnimationView(widget: widget, state: state, isSimulator: false)
                            case .anki:
                                WidgetAnkiView(widget: widget, state: state, isSimulator: false)
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
