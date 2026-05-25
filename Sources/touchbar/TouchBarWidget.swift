import Foundation

public enum WidgetType: String, Codable, CaseIterable, Sendable {
    case label = "Text Label"
    case button = "Button"
    case systemMonitor = "System Monitor"
    case media = "Media Controls"
    case animation = "Animation"
    case anki = "Anki Review"
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
    
    // Anki properties
    public var ankiDeckName: String
    public var ankiShowAgain: Bool
    public var ankiShowHard: Bool
    public var ankiShowGood: Bool
    public var ankiShowEasy: Bool
    public var ankiQuestionField: String
    public var ankiAnswerField: String
    
    // Clock properties
    public var showSeconds: Bool
    
    // Aesthetic properties
    public var fontSize: Double
    
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
        animationSpeed: Double = 0.2,
        ankiDeckName: String = "",
        ankiShowAgain: Bool = true,
        ankiShowHard: Bool = true,
        ankiShowGood: Bool = true,
        ankiShowEasy: Bool = true,
        ankiQuestionField: String = "Front",
        ankiAnswerField: String = "Back",
        showSeconds: Bool = true,
        fontSize: Double = 12.0
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
        self.ankiDeckName = ankiDeckName
        self.ankiShowAgain = ankiShowAgain
        self.ankiShowHard = ankiShowHard
        self.ankiShowGood = ankiShowGood
        self.ankiShowEasy = ankiShowEasy
        self.ankiQuestionField = ankiQuestionField
        self.ankiAnswerField = ankiAnswerField
        self.showSeconds = showSeconds
        self.fontSize = fontSize
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, iconName, backgroundColorHex, textColorHex
        case actionType, actionValue, monitorType, animationType, animationSpeed
        case ankiDeckName, ankiShowAgain, ankiShowHard, ankiShowGood, ankiShowEasy, ankiQuestionField, ankiAnswerField
        case showSeconds
        case fontSize
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(WidgetType.self, forKey: .type)
        self.title = try container.decode(String.self, forKey: .title)
        self.iconName = try container.decode(String.self, forKey: .iconName)
        self.backgroundColorHex = try container.decode(String.self, forKey: .backgroundColorHex)
        self.textColorHex = try container.decode(String.self, forKey: .textColorHex)
        
        self.actionType = try container.decode(ActionType.self, forKey: .actionType)
        self.actionValue = try container.decode(String.self, forKey: .actionValue)
        self.monitorType = try container.decode(MonitorType.self, forKey: .monitorType)
        self.animationType = try container.decode(AnimationPreset.self, forKey: .animationType)
        self.animationSpeed = try container.decode(Double.self, forKey: .animationSpeed)
        
        self.ankiDeckName = try container.decodeIfPresent(String.self, forKey: .ankiDeckName) ?? ""
        self.ankiShowAgain = try container.decodeIfPresent(Bool.self, forKey: .ankiShowAgain) ?? true
        self.ankiShowHard = try container.decodeIfPresent(Bool.self, forKey: .ankiShowHard) ?? true
        self.ankiShowGood = try container.decodeIfPresent(Bool.self, forKey: .ankiShowGood) ?? true
        self.ankiShowEasy = try container.decodeIfPresent(Bool.self, forKey: .ankiShowEasy) ?? true
        self.ankiQuestionField = try container.decodeIfPresent(String.self, forKey: .ankiQuestionField) ?? "Front"
        self.ankiAnswerField = try container.decodeIfPresent(String.self, forKey: .ankiAnswerField) ?? "Back"
        
        self.showSeconds = try container.decodeIfPresent(Bool.self, forKey: .showSeconds) ?? true
        self.fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 12.0
    }
}
