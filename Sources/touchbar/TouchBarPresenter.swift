import AppKit
import SwiftUI
import Foundation

@MainActor
public final class TouchBarPresenter: NSObject, NSTouchBarDelegate {
    @objc public static let shared = TouchBarPresenter()
    
    private let trayIdentifier = "com.touchbarcraft.systemtray"
    private var systemTrayItem: NSCustomTouchBarItem?
    private var globalTouchBar: NSTouchBar?
    
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
        // Remove existing item if any
        removeSystemTrayItem()
        
        let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier(trayIdentifier))
        
        // Beautiful sparkles button inside Control Strip
        let button = NSButton(
            image: NSImage(systemSymbolName: "sparkles", accessibilityDescription: "TouchBarCraft") ?? NSImage(),
            target: self,
            action: #selector(systemTrayButtonTapped)
        )
        button.bezelStyle = .rounded
        item.view = button
        self.systemTrayItem = item
        
        // Call private API: NSTouchBarItem.addSystemTrayItem(item)
        let addSelector = NSSelectorFromString("addSystemTrayItem:")
        if NSTouchBarItem.responds(to: addSelector) {
            NSTouchBarItem.perform(addSelector, with: item)
        }
        
        // Call private API: DFRElementSetControlStripPresenceForIdentifier(trayIdentifier, true)
        dfrelementSetControlStripPresenceForIdentifier?(trayIdentifier as CFString, true)
    }
    
    public func removeSystemTrayItem() {
        guard let item = systemTrayItem else { return }
        
        // Call private API: DFRElementSetControlStripPresenceForIdentifier(trayIdentifier, false)
        dfrelementSetControlStripPresenceForIdentifier?(trayIdentifier as CFString, false)
        
        // Call private API: NSTouchBarItem.removeSystemTrayItem(item)
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
        
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = state.widgets.map { NSTouchBarItem.Identifier($0.id.uuidString) }
        
        self.globalTouchBar = touchBar
        
        // Enable close box on system modal Touch Bar
        dfrSystemModalShowsCloseBoxWhenFrontMost?(true)
        
        // Call private API: NSTouchBar.presentSystemModalTouchBar(touchBar, systemTrayItemIdentifier: trayIdentifier)
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
        
        // Call private API: NSTouchBar.dismissSystemModalTouchBar(touchBar)
        let dismissSelector = NSSelectorFromString("dismissSystemModalTouchBar:")
        if NSTouchBar.responds(to: dismissSelector) {
            NSTouchBar.perform(dismissSelector, with: touchBar)
            print("System-wide Touch Bar dismissed.")
        }
        
        self.globalTouchBar = nil
    }
    
    @objc public static func refreshTouchBar() {
        // Ensure execution happens on main queue
        DispatchQueue.main.async {
            let presenter = TouchBarPresenter.shared
            
            // Re-present modal with updated layout
            if presenter.globalTouchBar != nil {
                presenter.presentGlobalTouchBar()
            }
        }
    }
    
    // MARK: - NSTouchBarDelegate
    
    public func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard let state = AppState.shared else { return nil }
        guard let widget = state.widgets.first(where: { $0.id.uuidString == identifier.rawValue }) else { return nil }
        
        let item = NSCustomTouchBarItem(identifier: identifier)
        
        // Render dynamic widgets in AppKit using SwiftUI NSHostingView!
        let hostView = NSHostingView(rootView: Group {
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
            }
        })
        
        // Set standard height for Apple Touch Bar views
        hostView.frame = NSRect(x: 0, y: 0, width: hostView.fittingSize.width, height: 30)
        item.view = hostView
        return item
    }
}
