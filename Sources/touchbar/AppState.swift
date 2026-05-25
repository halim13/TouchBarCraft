import Foundation
import SwiftUI
import Observation
import AppKit
import ServiceManagement

@Observable
@MainActor
public final class AppState {
    public static var shared: AppState? = nil
    
    public var widgets: [TouchBarWidget] = []
    public var selectedWidgetID: UUID?
    public var ankiState: AnkiState
    
    // Live system stats
    public var batteryLevel: Int = 100
    public var cpuUsage: Double = 0.0
    public var ramUsage: Double = 0.0
    public var currentTime: String = ""
    public var currentDate: String = ""
    
    private var statsTimer: Timer?
    private let configPath: URL
    
    public init() {
        // Setup config path in user's home directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.configPath = homeDir.appendingPathComponent(".touchbarcraft.json")
        self.ankiState = AnkiState()
        
        Self.shared = self
        loadConfig()
        startSystemTimers()
    }
    
    // MARK: - Persistence
    
    public func saveConfig() {
        do {
            let data = try JSONEncoder().encode(widgets)
            try data.write(to: configPath)
            print("Successfully saved configurations to \(configPath.path)")
            
            // Notify system presenter to refresh the physical Touch Bar layout!
            // We use NSSelectorFromString to avoid compile issues if presenter is not yet resolved
            let presenterClass: AnyClass? = NSClassFromString("touchbar.TouchBarPresenter")
            let refreshSelector = NSSelectorFromString("refreshTouchBar")
            if let presenter = presenterClass as? NSObject.Type {
                presenter.perform(refreshSelector)
            }
        } catch {
            print("Failed to save configurations: \(error.localizedDescription)")
        }
    }
    
    public func loadConfig() {
        if FileManager.default.fileExists(atPath: configPath.path) {
            do {
                let data = try Data(contentsOf: configPath)
                self.widgets = try JSONDecoder().decode([TouchBarWidget].self, from: data)
                if !widgets.isEmpty {
                    self.selectedWidgetID = widgets.first?.id
                    return
                }
            } catch {
                print("Failed to decode configurations, loading defaults: \(error.localizedDescription)")
            }
        }
        
        // Load beautiful default widgets
        loadDefaultWidgets()
    }
    
    public func loadDefaultWidgets() {
        self.widgets = [
            TouchBarWidget(
                type: .label,
                title: "👋 TouchBarCraft!",
                iconName: "sparkles",
                backgroundColorHex: "#8B5CF6", // Purple
                textColorHex: "#FFFFFF"
            ),
            TouchBarWidget(
                type: .label,
                title: "🕒 {time}",
                iconName: "clock",
                backgroundColorHex: "#3B82F6", // Blue
                textColorHex: "#FFFFFF"
            ),
            TouchBarWidget(
                type: .animation,
                title: "Pet",
                iconName: "pawprint.fill",
                backgroundColorHex: "#1E1E24",
                textColorHex: "#FFFFFF",
                animationType: .cat,
                animationSpeed: 0.15
            ),
            TouchBarWidget(
                type: .button,
                title: "Mute Sound",
                iconName: "speaker.slash",
                backgroundColorHex: "#EF4444", // Red
                textColorHex: "#FFFFFF",
                actionType: .playSound,
                actionValue: "Basso"
            ),
            TouchBarWidget(
                type: .button,
                title: "Dark Mode",
                iconName: "moon.stars.fill",
                backgroundColorHex: "#4B5563", // Gray
                textColorHex: "#FFFFFF",
                actionType: .toggleDarkMode
            ),
            TouchBarWidget(
                type: .systemMonitor,
                title: "CPU",
                iconName: "cpu",
                backgroundColorHex: "#10B981", // Emerald
                textColorHex: "#FFFFFF",
                monitorType: .cpu
            ),
            TouchBarWidget(
                type: .media,
                title: "Music",
                iconName: "music.note",
                backgroundColorHex: "#EC4899", // Pink
                textColorHex: "#FFFFFF"
            )
        ]
        self.selectedWidgetID = self.widgets.first?.id
        saveConfig()
    }
    
    // MARK: - Actions
    
    public func executeAction(for widget: TouchBarWidget) {
        guard widget.type == .button else { return }
        
        switch widget.actionType {
        case .none:
            break
            
        case .shellCommand:
            let command = widget.actionValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { return }
            
            // Execute shell command asynchronously
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]
                
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    print("Failed to run shell command: \(error.localizedDescription)")
                }
            }
            
        case .playSound:
            let soundName = widget.actionValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !soundName.isEmpty, let sound = NSSound(named: soundName) {
                sound.play()
            } else {
                NSSound(named: "Glass")?.play()
            }
            
        case .toggleDarkMode:
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = """
                tell application "System Events"
                    tell appearance preferences
                        set dark mode to not dark mode
                    end tell
                end tell
                """
                if let script = NSAppleScript(source: appleScript) {
                    var error: NSDictionary?
                    script.executeAndReturnError(&error)
                }
            }
            
        case .lockScreen:
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
                process.arguments = ["sleepnow"]
                do {
                    try process.run()
                } catch {
                    print("Failed to lock screen: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Widget Management
    
    public func addWidget(_ type: WidgetType) {
        let newWidget: TouchBarWidget
        switch type {
        case .label:
            newWidget = TouchBarWidget(
                type: .label,
                title: "New Label {time}",
                iconName: "tag",
                backgroundColorHex: "#3B82F6"
            )
        case .button:
            newWidget = TouchBarWidget(
                type: .button,
                title: "Run Command",
                iconName: "terminal",
                backgroundColorHex: "#10B981",
                actionType: .shellCommand,
                actionValue: "say hello"
            )
        case .systemMonitor:
            newWidget = TouchBarWidget(
                type: .systemMonitor,
                title: "RAM Monitor",
                iconName: "memorychip",
                backgroundColorHex: "#F59E0B",
                monitorType: .ram
            )
        case .media:
            newWidget = TouchBarWidget(
                type: .media,
                title: "Media Controller",
                iconName: "playpause.fill",
                backgroundColorHex: "#EC4899"
            )
        case .animation:
            newWidget = TouchBarWidget(
                type: .animation,
                title: "Cat Anim",
                iconName: "pawprint",
                backgroundColorHex: "#6B7280",
                animationType: .cat,
                animationSpeed: 0.15
            )
        case .anki:
            newWidget = TouchBarWidget(
                type: .anki,
                title: "Anki Review",
                iconName: "rectangle.stack.fill",
                backgroundColorHex: "#2563EB",
                textColorHex: "#FFFFFF"
            )
        }
        
        widgets.append(newWidget)
        selectedWidgetID = newWidget.id
        saveConfig()
    }
    
    public func deleteWidget(id: UUID) {
        widgets.removeAll { $0.id == id }
        if selectedWidgetID == id {
            selectedWidgetID = widgets.first?.id
        }
        saveConfig()
    }
    
    public func moveWidget(from source: IndexSet, to destination: Int) {
        widgets.move(fromOffsets: source, toOffset: destination)
        saveConfig()
    }
    
    // MARK: - Timers & System Info Updates
    
    private func startSystemTimers() {
        // First initial values
        updateSystemInfo()
        
        // Update stats and time every 1.0 seconds
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemInfo()
            }
        }
    }
    
    private func updateSystemInfo() {
        let formatterTime = DateFormatter()
        formatterTime.dateFormat = "HH:mm:ss"
        self.currentTime = formatterTime.string(from: Date())
        
        let formatterDate = DateFormatter()
        formatterDate.dateFormat = "E, d MMM"
        self.currentDate = formatterDate.string(from: Date())
        
        // Query system monitor helper
        self.batteryLevel = SystemMonitorHelper.shared.getBatteryPercentage()
        self.cpuUsage = SystemMonitorHelper.shared.getCPUUsage()
        self.ramUsage = SystemMonitorHelper.shared.getRAMUsage()
    }
    
    // MARK: - Autostart / Launch at Login
    
    public var isLaunchAtLoginEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                let status = SMAppService.mainApp.status
                return status == .enabled
            }
            return false
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                        print("SMAppService successfully registered main app for autostart.")
                    } else {
                        try SMAppService.mainApp.unregister()
                        print("SMAppService successfully unregistered main app for autostart.")
                    }
                } catch {
                    print("Failed to toggle autostart: \(error.localizedDescription)")
                }
            }
        }
    }
}
