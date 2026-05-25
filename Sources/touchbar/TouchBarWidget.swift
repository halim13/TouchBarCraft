import Foundation

public enum WidgetType: String, Codable, CaseIterable, Sendable {
    case label = "Text Label"
    case button = "Button"
    case systemMonitor = "System Monitor"
    case media = "Media Controls"
    case animation = "Animation"
}

public enum ActionType: String, Codable, CaseIterable, Sendable {
    case none = "None"
    case shellCommand = "Shell Command"
    case playSound = "Play Sound"
    case toggleDarkMode = "Toggle Dark Mode"
    case lockScreen = "Lock Screen"
}

public enum MonitorType: String, Codable, CaseIterable, Sendable {
    case cpu = "CPU Usage"
    case ram = "RAM Usage"
    case battery = "Battery Level"
}

public enum AnimationPreset: String, Codable, CaseIterable, Sendable {
    case cat = "Walking Cat 🐱🐾"
    case heart = "Pulsing Heart ❤️"
    case spinner = "Spinning Wheel 🎡"
    case coffee = "Coffee Brewing ☕️"
    case matrix = "Matrix Rain 💾"
}

public struct TouchBarWidget: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var type: WidgetType
    public var title: String
    public var iconName: String // SF Symbol name
    public var backgroundColorHex: String
    public var textColorHex: String
    
    // Button properties
    public var actionType: ActionType
    public var actionValue: String // command string or sound name
    
    // Monitor properties
    public var monitorType: MonitorType
    
    // Animation properties
    public var animationType: AnimationPreset
    public var animationSpeed: Double // in seconds per frame
    
    public init(
        id: UUID = UUID(),
        type: WidgetType = .label,
        title: String = "Widget",
        iconName: String = "info.circle",
        backgroundColorHex: String = "#1E1E24",
        textColorHex: String = "#FFFFFF",
        actionType: ActionType = .none,
        actionValue: String = "",
        monitorType: MonitorType = .cpu,
        animationType: AnimationPreset = .cat,
        animationSpeed: Double = 0.2
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.iconName = iconName
        self.backgroundColorHex = backgroundColorHex
        self.textColorHex = textColorHex
        self.actionType = actionType
        self.actionValue = actionValue
        self.monitorType = monitorType
        self.animationType = animationType
        self.animationSpeed = animationSpeed
    }
}
