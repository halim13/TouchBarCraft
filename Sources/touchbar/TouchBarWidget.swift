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
    case nhkNews = "NHK Easy News"
    case dock = "Dock"
    case appLauncher = "App Launcher"
    case prayerTime = "Prayer Time"
}

public enum ActionType: String, Codable, CaseIterable, Sendable {
    case none = "None"
    case shellCommand = "Shell Command"
    case appleScript = "AppleScript"
    case playSound = "Play Sound"
    case toggleDarkMode = "Toggle Dark Mode"
    case lockScreen = "Lock Screen"
    case brightnessUp = "Brightness Up"
    case brightnessDown = "Brightness Down"
    case volumeUp = "Volume Up"
    case volumeDown = "Volume Down"
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

public enum AnkiScrollMode: String, Codable, CaseIterable, Sendable {
    case none = "None"
    case answerOnly = "Answer Only"
    case both = "Both (Question & Answer)"
}

public struct AnkiDeckSettings: Codable, Hashable, Sendable {
    public var questionField: String
    public var answerField: String
    public var audioField: String
    public var touchBarAudioField: String
    public var extraQuestionField: String
    public var extraAnswerField: String
    public var overlayQuestionField: String
    public var overlayAnswerField: String
    public var overlayAudioField: String
    public var overlayExtraQuestionField: String
    public var overlayExtraAnswerField: String
    public var overlayBoldColorHex: String
    public var overlayExtraQuestionOnlyOnAnswer: Bool
    public var frontTemplate: String
    public var backTemplate: String
    public var templateCss: String
    
    public init(questionField: String, answerField: String, audioField: String, touchBarAudioField: String = "Audio", extraQuestionField: String = "", extraAnswerField: String = "", overlayQuestionField: String = "", overlayAnswerField: String = "", overlayAudioField: String = "", overlayExtraQuestionField: String = "", overlayExtraAnswerField: String = "", overlayBoldColorHex: String = "", overlayExtraQuestionOnlyOnAnswer: Bool = false, frontTemplate: String = "", backTemplate: String = "", templateCss: String = "") {
        self.questionField = questionField
        self.answerField = answerField
        self.audioField = audioField
        self.touchBarAudioField = touchBarAudioField
        self.extraQuestionField = extraQuestionField
        self.extraAnswerField = extraAnswerField
        self.overlayQuestionField = overlayQuestionField
        self.overlayAnswerField = overlayAnswerField
        self.overlayAudioField = overlayAudioField
        self.overlayExtraQuestionField = overlayExtraQuestionField
        self.overlayExtraAnswerField = overlayExtraAnswerField
        self.overlayBoldColorHex = overlayBoldColorHex
        self.overlayExtraQuestionOnlyOnAnswer = overlayExtraQuestionOnlyOnAnswer
        self.frontTemplate = frontTemplate
        self.backTemplate = backTemplate
        self.templateCss = templateCss
    }

    enum CodingKeys: String, CodingKey {
        case questionField, answerField, audioField, touchBarAudioField
        case extraQuestionField, extraAnswerField
        case overlayQuestionField, overlayAnswerField, overlayAudioField
        case overlayExtraQuestionField, overlayExtraAnswerField, overlayBoldColorHex, overlayExtraQuestionOnlyOnAnswer
        case frontTemplate, backTemplate, templateCss
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.questionField = try container.decodeIfPresent(String.self, forKey: .questionField) ?? ""
        self.answerField = try container.decodeIfPresent(String.self, forKey: .answerField) ?? ""
        self.audioField = try container.decodeIfPresent(String.self, forKey: .audioField) ?? "Audio"
        self.touchBarAudioField = try container.decodeIfPresent(String.self, forKey: .touchBarAudioField) ?? self.audioField
        self.extraQuestionField = try container.decodeIfPresent(String.self, forKey: .extraQuestionField) ?? ""
        self.extraAnswerField = try container.decodeIfPresent(String.self, forKey: .extraAnswerField) ?? ""
        self.overlayQuestionField = try container.decodeIfPresent(String.self, forKey: .overlayQuestionField) ?? ""
        self.overlayAnswerField = try container.decodeIfPresent(String.self, forKey: .overlayAnswerField) ?? ""
        self.overlayAudioField = try container.decodeIfPresent(String.self, forKey: .overlayAudioField) ?? ""
        self.overlayExtraQuestionField = try container.decodeIfPresent(String.self, forKey: .overlayExtraQuestionField) ?? ""
        self.overlayExtraAnswerField = try container.decodeIfPresent(String.self, forKey: .overlayExtraAnswerField) ?? ""
        self.overlayBoldColorHex = try container.decodeIfPresent(String.self, forKey: .overlayBoldColorHex) ?? ""
        self.overlayExtraQuestionOnlyOnAnswer = try container.decodeIfPresent(Bool.self, forKey: .overlayExtraQuestionOnlyOnAnswer) ?? false
        self.frontTemplate = try container.decodeIfPresent(String.self, forKey: .frontTemplate) ?? ""
        self.backTemplate = try container.decodeIfPresent(String.self, forKey: .backTemplate) ?? ""
        self.templateCss = try container.decodeIfPresent(String.self, forKey: .templateCss) ?? ""
    }
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
    public var ankiTouchBarAudioField: String
    public var ankiExtraQuestionField: String
    public var ankiExtraAnswerField: String
    public var ankiTextMaxWidth: Double
    public var ankiTextMaxWidthNoText: Double
    public var ankiDeckSettings: [String: AnkiDeckSettings]
    
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
    
    // Anki rating button custom colors
    public var ankiAgainColorHex: String
    public var ankiHardColorHex: String
    public var ankiGoodColorHex: String
    public var ankiEasyColorHex: String
    
    // Anki mute state persistence
    public var ankiIsMuted: Bool

    // Anki show remaining counts toggle
    public var ankiShowRemainingCounts: Bool

    // Anki show button interval durations (e.g. "30d", "35m")
    public var ankiShowButtonsInterval: Bool
    
    // NHK furigana font size (0 = auto)
    public var nhkFuriganaFontSize: Double

    // NHK furigana text color hex
    public var nhkFuriganaColorHex: String

    // NHK navigation buttons on left side
    public var nhkNavOnLeft: Bool

    // Anki combine furigana toggle
    public var ankiCombineFurigana: Bool
    
    // Anki manual furigana font size (0 = auto/clamp)
    public var ankiFuriganaFontSize: Double
    
    // Anki furigana vertical offset adjustment (pt). Positive = move up, negative = move down.
    public var ankiFuriganaVerticalOffset: Double

    // Anki offset for base text in segments that have furigana, in furigana mode.
    // Applies to both question and answer.
    public var ankiFuriganaSegmentOffset: Double

    // Anki offset for base text in segments that don't have furigana.
    // Used in both furigana mode (non-furigana segments) and non-furigana mode (all text).
    // Applies to both question and answer.
    public var ankiNonFuriganaSegmentOffset: Double
    
    // Anki audio play only after answer is revealed
    public var ankiAudioOnlyOnAnswer: Bool

    // Anki trim text with trailing tail (ellipsis)
    public var ankiTrimText: Bool
    
    // Anki horizontal scroll mode
    public var ankiScrollMode: AnkiScrollMode

    // Anki tap on TouchBar shows extra field content instead of playing audio
    public var ankiTapShowsExtra: Bool

    // Hide card text from Touch Bar, show only buttons (reveal, rating, audio, sync)
    public var ankiHideTextOnTouchBar: Bool

    // Long press on single rating button to submit alternative ease
    public var ankiEnableLongPress: Bool
    public var ankiLongPressDuration: Double
    public var ankiLongPressRating: Int

    // Animation Custom properties
    public var customGifPath: String
    
    // Hidden state (hide from Touch Bar without deleting config)
    public var isHidden: Bool

    // Hide only from Touch Bar but keep keyboard shortcuts & floating windows
    public var hideFromTouchBar: Bool

    // Custom Width setting
    public var customWidth: Double

    // App Launcher: bundle identifiers of apps to show
    public var appLauncherApps: [String]

    // Prayer Time properties
    public var prayerApiKey: String
    public var prayerLatitude: String
    public var prayerLongitude: String
    public var prayerMethod: Int
    public var prayerSchool: Int
    public var prayerUseCustomTimes: Bool
    public var prayerCustomTimes: [String: String]
    public var prayerAdzanAlertEnabled: Bool
    public var prayerAdzanIcon: String
    public var prayerAdzanText: String
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
        ankiTouchBarAudioField: String = "Audio",
        ankiExtraQuestionField: String = "",
        ankiExtraAnswerField: String = "",
        ankiTextMaxWidth: Double = 250.0,
        ankiTextMaxWidthNoText: Double = 150.0,
        ankiDeckSettings: [String: AnkiDeckSettings] = [:],
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
        ankiIsMuted: Bool = false,
        ankiShowRemainingCounts: Bool = false,
        ankiShowButtonsInterval: Bool = true,
        nhkFuriganaFontSize: Double = 0,
        nhkFuriganaColorHex: String = "#FFFFFF",
        nhkNavOnLeft: Bool = false,
        ankiCombineFurigana: Bool = false,
        ankiFuriganaFontSize: Double = 0,
        ankiFuriganaVerticalOffset: Double = 0,
        ankiFuriganaSegmentOffset: Double = 0,
        ankiNonFuriganaSegmentOffset: Double = 0,
        ankiAgainColorHex: String = "#E53333",
        ankiHardColorHex: String = "#E58019",
        ankiGoodColorHex: String = "#19B24C",
        ankiEasyColorHex: String = "#3380E5",
        ankiAudioOnlyOnAnswer: Bool = true,
        ankiTrimText: Bool = true,
        ankiScrollMode: AnkiScrollMode = .answerOnly,
        ankiTapShowsExtra: Bool = false,
        ankiHideTextOnTouchBar: Bool = false,
        ankiEnableLongPress: Bool = false,
        ankiLongPressDuration: Double = 0.5,
        ankiLongPressRating: Int = 2,
        customGifPath: String = "",
        isHidden: Bool = false,
        hideFromTouchBar: Bool = false,
        customWidth: Double = 0.0,
        appLauncherApps: [String] = [],
        prayerApiKey: String = "",
        prayerLatitude: String = "",
        prayerLongitude: String = "",
        prayerMethod: Int = 3,
        prayerSchool: Int = 1,
        prayerUseCustomTimes: Bool = false,
        prayerCustomTimes: [String: String] = [:],
        prayerAdzanAlertEnabled: Bool = false,
        prayerAdzanIcon: String = "",
        prayerAdzanText: String = ""
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
        self.ankiTouchBarAudioField = ankiTouchBarAudioField
        self.ankiExtraQuestionField = ankiExtraQuestionField
        self.ankiExtraAnswerField = ankiExtraAnswerField
        self.ankiTextMaxWidth = ankiTextMaxWidth
        self.ankiTextMaxWidthNoText = ankiTextMaxWidthNoText
        self.ankiDeckSettings = ankiDeckSettings
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
        self.ankiIsMuted = ankiIsMuted
        self.ankiShowRemainingCounts = ankiShowRemainingCounts
        self.ankiShowButtonsInterval = ankiShowButtonsInterval
        self.nhkFuriganaFontSize = nhkFuriganaFontSize
        self.nhkFuriganaColorHex = nhkFuriganaColorHex
        self.nhkNavOnLeft = nhkNavOnLeft
        self.ankiCombineFurigana = ankiCombineFurigana
        self.ankiFuriganaFontSize = ankiFuriganaFontSize
        self.ankiFuriganaVerticalOffset = ankiFuriganaVerticalOffset
        self.ankiFuriganaSegmentOffset = ankiFuriganaSegmentOffset
        self.ankiNonFuriganaSegmentOffset = ankiNonFuriganaSegmentOffset
        self.ankiAgainColorHex = ankiAgainColorHex
        self.ankiHardColorHex = ankiHardColorHex
        self.ankiGoodColorHex = ankiGoodColorHex
        self.ankiEasyColorHex = ankiEasyColorHex
        self.ankiAudioOnlyOnAnswer = ankiAudioOnlyOnAnswer
        self.ankiTrimText = ankiTrimText
        self.ankiScrollMode = ankiScrollMode
        self.ankiTapShowsExtra = ankiTapShowsExtra
        self.ankiHideTextOnTouchBar = ankiHideTextOnTouchBar
        self.ankiEnableLongPress = ankiEnableLongPress
        self.ankiLongPressDuration = ankiLongPressDuration
        self.ankiLongPressRating = ankiLongPressRating
        self.customGifPath = customGifPath
        self.isHidden = isHidden
        self.hideFromTouchBar = hideFromTouchBar
        self.customWidth = customWidth
        self.appLauncherApps = appLauncherApps
        self.prayerApiKey = prayerApiKey
        self.prayerLatitude = prayerLatitude
        self.prayerLongitude = prayerLongitude
        self.prayerMethod = prayerMethod
        self.prayerSchool = prayerSchool
        self.prayerUseCustomTimes = prayerUseCustomTimes
        self.prayerCustomTimes = prayerCustomTimes
        self.prayerAdzanAlertEnabled = prayerAdzanAlertEnabled
        self.prayerAdzanIcon = prayerAdzanIcon
        self.prayerAdzanText = prayerAdzanText
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, iconName, backgroundColorHex, textColorHex
        case actionType, actionValue, longPressActionType, longPressActionValue, monitorType, animationType, animationSpeed
        case ankiDeckName, ankiShowAgain, ankiShowHard, ankiShowGood, ankiShowEasy, ankiQuestionField, ankiAnswerField, ankiAudioField, ankiTouchBarAudioField, ankiExtraQuestionField, ankiExtraAnswerField, ankiTextMaxWidth, ankiTextMaxWidthNoText, ankiDeckSettings
        case showSeconds
        case fontSize, brightnessButtonSize, volumeSliderWidth, volumeShowIcon
        case batteryDisplayType, batteryChargingIcon, batteryFullIcon, batteryLowIcon, batteryNormalIcon, batteryLowThreshold, batteryFullThreshold
        case ankiBoldColorHex
        case ankiIsMuted
        case ankiShowRemainingCounts
        case ankiShowButtonsInterval
        case nhkFuriganaFontSize
        case nhkFuriganaColorHex
        case nhkNavOnLeft
        case ankiCombineFurigana
        case ankiFuriganaFontSize
        case ankiFuriganaVerticalOffset
        case ankiFuriganaSegmentOffset
        case ankiNonFuriganaSegmentOffset
        case ankiAgainColorHex
        case ankiHardColorHex
        case ankiGoodColorHex
        case ankiEasyColorHex
        case ankiAudioOnlyOnAnswer
        case ankiTrimText
        case ankiScrollMode
        case ankiTapShowsExtra
        case ankiHideTextOnTouchBar
        case ankiEnableLongPress, ankiLongPressDuration, ankiLongPressRating
        case customGifPath
        case isHidden
        case hideFromTouchBar
        case customWidth
        case appLauncherApps
        case prayerApiKey, prayerLatitude, prayerLongitude, prayerMethod, prayerSchool
        case prayerUseCustomTimes, prayerCustomTimes
        case prayerAdzanAlertEnabled
        case prayerAdzanIcon, prayerAdzanText
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
        self.ankiTouchBarAudioField = try container.decodeIfPresent(String.self, forKey: .ankiTouchBarAudioField) ?? self.ankiAudioField
        self.ankiExtraQuestionField = try container.decodeIfPresent(String.self, forKey: .ankiExtraQuestionField) ?? ""
        self.ankiExtraAnswerField = try container.decodeIfPresent(String.self, forKey: .ankiExtraAnswerField) ?? ""
        self.ankiTextMaxWidth = try container.decodeIfPresent(Double.self, forKey: .ankiTextMaxWidth) ?? 250.0
        self.ankiTextMaxWidthNoText = try container.decodeIfPresent(Double.self, forKey: .ankiTextMaxWidthNoText) ?? 150.0
        self.ankiDeckSettings = try container.decodeIfPresent([String: AnkiDeckSettings].self, forKey: .ankiDeckSettings) ?? [:]
        
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
        self.ankiIsMuted = try container.decodeIfPresent(Bool.self, forKey: .ankiIsMuted) ?? false
        self.ankiShowRemainingCounts = try container.decodeIfPresent(Bool.self, forKey: .ankiShowRemainingCounts) ?? false
        self.ankiShowButtonsInterval = try container.decodeIfPresent(Bool.self, forKey: .ankiShowButtonsInterval) ?? true
        self.nhkFuriganaFontSize = try container.decodeIfPresent(Double.self, forKey: .nhkFuriganaFontSize) ?? 0
        self.nhkFuriganaColorHex = try container.decodeIfPresent(String.self, forKey: .nhkFuriganaColorHex) ?? "#FFFFFF"
        self.nhkNavOnLeft = try container.decodeIfPresent(Bool.self, forKey: .nhkNavOnLeft) ?? false
        self.ankiCombineFurigana = try container.decodeIfPresent(Bool.self, forKey: .ankiCombineFurigana) ?? false
        self.ankiFuriganaFontSize = try container.decodeIfPresent(Double.self, forKey: .ankiFuriganaFontSize) ?? 0
        self.ankiFuriganaVerticalOffset = try container.decodeIfPresent(Double.self, forKey: .ankiFuriganaVerticalOffset) ?? 0
        self.ankiFuriganaSegmentOffset = try container.decodeIfPresent(Double.self, forKey: .ankiFuriganaSegmentOffset) ?? 0
        self.ankiNonFuriganaSegmentOffset = try container.decodeIfPresent(Double.self, forKey: .ankiNonFuriganaSegmentOffset) ?? 0
        self.ankiAgainColorHex = try container.decodeIfPresent(String.self, forKey: .ankiAgainColorHex) ?? "#E53333"
        self.ankiHardColorHex = try container.decodeIfPresent(String.self, forKey: .ankiHardColorHex) ?? "#E58019"
        self.ankiGoodColorHex = try container.decodeIfPresent(String.self, forKey: .ankiGoodColorHex) ?? "#19B24C"
        self.ankiEasyColorHex = try container.decodeIfPresent(String.self, forKey: .ankiEasyColorHex) ?? "#3380E5"
        self.ankiAudioOnlyOnAnswer = try container.decodeIfPresent(Bool.self, forKey: .ankiAudioOnlyOnAnswer) ?? true
        self.ankiTrimText = try container.decodeIfPresent(Bool.self, forKey: .ankiTrimText) ?? true
        self.ankiScrollMode = (try? container.decodeIfPresent(AnkiScrollMode.self, forKey: .ankiScrollMode))
            ?? (ankiTrimText ? .both : .none)
        self.ankiTapShowsExtra = try container.decodeIfPresent(Bool.self, forKey: .ankiTapShowsExtra) ?? false
        self.ankiHideTextOnTouchBar = try container.decodeIfPresent(Bool.self, forKey: .ankiHideTextOnTouchBar) ?? false
        self.ankiEnableLongPress = try container.decodeIfPresent(Bool.self, forKey: .ankiEnableLongPress) ?? false
        self.ankiLongPressDuration = try container.decodeIfPresent(Double.self, forKey: .ankiLongPressDuration) ?? 0.5
        self.ankiLongPressRating = try container.decodeIfPresent(Int.self, forKey: .ankiLongPressRating) ?? 2
        
        self.customGifPath = try container.decodeIfPresent(String.self, forKey: .customGifPath) ?? ""
        self.isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        self.hideFromTouchBar = try container.decodeIfPresent(Bool.self, forKey: .hideFromTouchBar) ?? false
        self.customWidth = try container.decodeIfPresent(Double.self, forKey: .customWidth) ?? 0.0
        self.appLauncherApps = try container.decodeIfPresent([String].self, forKey: .appLauncherApps) ?? []
        self.prayerApiKey = try container.decodeIfPresent(String.self, forKey: .prayerApiKey) ?? ""
        self.prayerLatitude = try container.decodeIfPresent(String.self, forKey: .prayerLatitude) ?? ""
        self.prayerLongitude = try container.decodeIfPresent(String.self, forKey: .prayerLongitude) ?? ""
        self.prayerMethod = try container.decodeIfPresent(Int.self, forKey: .prayerMethod) ?? 3
        self.prayerSchool = try container.decodeIfPresent(Int.self, forKey: .prayerSchool) ?? 1
        self.prayerUseCustomTimes = try container.decodeIfPresent(Bool.self, forKey: .prayerUseCustomTimes) ?? false
        self.prayerCustomTimes = try container.decodeIfPresent([String: String].self, forKey: .prayerCustomTimes) ?? [:]
        self.prayerAdzanAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .prayerAdzanAlertEnabled) ?? false
        self.prayerAdzanIcon = try container.decodeIfPresent(String.self, forKey: .prayerAdzanIcon) ?? ""
        self.prayerAdzanText = try container.decodeIfPresent(String.self, forKey: .prayerAdzanText) ?? ""
    }
}
