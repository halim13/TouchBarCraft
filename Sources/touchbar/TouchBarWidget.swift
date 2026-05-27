import Foundation

public enum WidgetType: String, Codable, CaseIterable, Sendable {
    case label = "Text Label"
    case button = "Button"
    case systemMonitor = "System Monitor"
    case media = "Media Controls"
    case animation = "Animation"
    case anki = "Anki Review"
    case volumeSlider = "Volume Slider"
    case brightnessButtons = "Brightness Controls"
}

public enum ActionType: String, Codable, CaseIterable, Sendable {
    case none = "None"
    case shellCommand = "Shell Command"
    case appleScript = "AppleScript"
    case playSound = "Play Sound"
    case toggleDarkMode = "Toggle Dark Mode"
    case lockScreen = "Lock Screen"
}

public enum MonitorType: String, Codable, CaseIterable, Sendable {
    case cpu = "CPU Usage"
    case ram = "RAM Usage"
    case battery = "Battery Level"
}

public enum BatteryDisplayType: String, Codable, CaseIterable, Sendable {
    case textOnly = "Text Only"
    case imageOrAnimation = "Image or Animation"
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
    
    // Action properties
    public var actionType: ActionType
    public var actionValue: String // command string or sound name
    public var longPressActionType: ActionType
    public var longPressActionValue: String
    
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
    public var ankiAudioField: String
    public var ankiTextMaxWidth: Double
    
    // Clock properties
    public var showSeconds: Bool
    
    // Brightness buttons properties
    public var brightnessButtonSize: Double // button width in simulator
    
    // Volume slider properties
    public var volumeSliderWidth: Double
    public var volumeShowIcon: Bool
    
    // Aesthetic properties
    public var fontSize: Double
    
    // Battery custom icons & settings
    public var batteryDisplayType: BatteryDisplayType
    public var batteryChargingIcon: String
    public var batteryFullIcon: String
    public var batteryLowIcon: String
    public var batteryNormalIcon: String
    public var batteryLowThreshold: Int
    public var batteryFullThreshold: Int
    
    // Anki bold custom color
    public var ankiBoldColorHex: String

    // Animation Custom properties
    public var customGifPath: String
    
    // Custom Width setting
    public var customWidth: Double
    
    public init(
        id: UUID = UUID(),
        type: WidgetType = .label,
        title: String = "Widget",
        iconName: String = "info.circle",
        backgroundColorHex: String = "#1E1E24",
        textColorHex: String = "#FFFFFF",
        actionType: ActionType = .none,
        actionValue: String = "",
        longPressActionType: ActionType = .none,
        longPressActionValue: String = "",
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
        ankiAudioField: String = "Audio",
        ankiTextMaxWidth: Double = 250.0,
        showSeconds: Bool = true,
        fontSize: Double = 12.0,
        brightnessButtonSize: Double = 16.0,
        volumeSliderWidth: Double = 150.0,
        volumeShowIcon: Bool = true,
        batteryDisplayType: BatteryDisplayType = .imageOrAnimation,
        batteryChargingIcon: String = "",
        batteryFullIcon: String = "",
        batteryLowIcon: String = "",
        batteryNormalIcon: String = "",
        batteryLowThreshold: Int = 20,
        batteryFullThreshold: Int = 85,
        ankiBoldColorHex: String = "#FFD60A",
        customGifPath: String = "",
        customWidth: Double = 0.0
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.iconName = iconName
        self.backgroundColorHex = backgroundColorHex
        self.textColorHex = textColorHex
        self.actionType = actionType
        self.actionValue = actionValue
        self.longPressActionType = longPressActionType
        self.longPressActionValue = longPressActionValue
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
        self.ankiAudioField = ankiAudioField
        self.ankiTextMaxWidth = ankiTextMaxWidth
        self.showSeconds = showSeconds
        self.fontSize = fontSize
        self.brightnessButtonSize = brightnessButtonSize
        self.volumeSliderWidth = volumeSliderWidth
        self.volumeShowIcon = volumeShowIcon
        self.batteryDisplayType = batteryDisplayType
        self.batteryChargingIcon = batteryChargingIcon
        self.batteryFullIcon = batteryFullIcon
        self.batteryLowIcon = batteryLowIcon
        self.batteryNormalIcon = batteryNormalIcon
        self.batteryLowThreshold = batteryLowThreshold
        self.batteryFullThreshold = batteryFullThreshold
        self.ankiBoldColorHex = ankiBoldColorHex
        self.customGifPath = customGifPath
        self.customWidth = customWidth
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, iconName, backgroundColorHex, textColorHex
        case actionType, actionValue, longPressActionType, longPressActionValue, monitorType, animationType, animationSpeed
        case ankiDeckName, ankiShowAgain, ankiShowHard, ankiShowGood, ankiShowEasy, ankiQuestionField, ankiAnswerField, ankiAudioField, ankiTextMaxWidth
        case showSeconds
        case fontSize, brightnessButtonSize, volumeSliderWidth, volumeShowIcon
        case batteryDisplayType, batteryChargingIcon, batteryFullIcon, batteryLowIcon, batteryNormalIcon, batteryLowThreshold, batteryFullThreshold
        case ankiBoldColorHex
        case customGifPath
        case customWidth
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
        self.longPressActionType = try container.decodeIfPresent(ActionType.self, forKey: .longPressActionType) ?? .none
        self.longPressActionValue = try container.decodeIfPresent(String.self, forKey: .longPressActionValue) ?? ""
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
        self.ankiAudioField = try container.decodeIfPresent(String.self, forKey: .ankiAudioField) ?? "Audio"
        self.ankiTextMaxWidth = try container.decodeIfPresent(Double.self, forKey: .ankiTextMaxWidth) ?? 250.0
        
        self.showSeconds = try container.decodeIfPresent(Bool.self, forKey: .showSeconds) ?? true
        self.fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 12.0
        self.brightnessButtonSize = try container.decodeIfPresent(Double.self, forKey: .brightnessButtonSize) ?? 16.0
        self.volumeSliderWidth = try container.decodeIfPresent(Double.self, forKey: .volumeSliderWidth) ?? 150.0
        self.volumeShowIcon = try container.decodeIfPresent(Bool.self, forKey: .volumeShowIcon) ?? true
        
        self.batteryDisplayType = try container.decodeIfPresent(BatteryDisplayType.self, forKey: .batteryDisplayType) ?? .imageOrAnimation
        self.batteryChargingIcon = try container.decodeIfPresent(String.self, forKey: .batteryChargingIcon) ?? ""
        self.batteryFullIcon = try container.decodeIfPresent(String.self, forKey: .batteryFullIcon) ?? ""
        self.batteryLowIcon = try container.decodeIfPresent(String.self, forKey: .batteryLowIcon) ?? ""
        self.batteryNormalIcon = try container.decodeIfPresent(String.self, forKey: .batteryNormalIcon) ?? ""
        self.batteryLowThreshold = try container.decodeIfPresent(Int.self, forKey: .batteryLowThreshold) ?? 20
        self.batteryFullThreshold = try container.decodeIfPresent(Int.self, forKey: .batteryFullThreshold) ?? 85
        
        self.ankiBoldColorHex = try container.decodeIfPresent(String.self, forKey: .ankiBoldColorHex) ?? "#FFD60A"
        
        self.customGifPath = try container.decodeIfPresent(String.self, forKey: .customGifPath) ?? ""
        self.customWidth = try container.decodeIfPresent(Double.self, forKey: .customWidth) ?? 0.0
    }
}
