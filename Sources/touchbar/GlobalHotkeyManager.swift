import Foundation
import Carbon
import AppKit

// MARK: - Hotkey Action Enum

public enum AnkiHotkeyAction: Int, CaseIterable, Codable, Sendable {
    case connect    = 1
    case reveal     = 2
    case sync       = 3
    case rating1    = 4 // Again
    case rating2    = 5 // Hard
    case rating3    = 6 // Good
    case rating4    = 7 // Easy
    case audio      = 8
    case touchBarAudio = 9
    case toggleOverlay = 10
    case toggleNHKFloatingWindow = 11

    public var displayName: String {
        switch self {
        case .connect:       return "Connect"
        case .reveal:        return "Reveal Answer"
        case .sync:          return "Sync"
        case .rating1:       return "Rating: Again"
        case .rating2:       return "Rating: Hard"
        case .rating3:       return "Rating: Good"
        case .rating4:       return "Rating: Easy"
        case .audio:         return "Toggle Audio"
        case .touchBarAudio: return "Toggle Touch Bar Audio"
        case .toggleOverlay: return "Toggle Floating Overlay"
        case .toggleNHKFloatingWindow: return "Toggle NHK Floating Window"
        }
    }

    public var iconName: String {
        switch self {
        case .connect:       return "link"
        case .reveal:        return "eye.fill"
        case .sync:          return "arrow.triangle.2.circlepath"
        case .rating1:       return "1.circle.fill"
        case .rating2:       return "2.circle.fill"
        case .rating3:       return "3.circle.fill"
        case .rating4:       return "4.circle.fill"
        case .audio:         return "speaker.wave.2.fill"
        case .touchBarAudio: return "speaker.wave.2"
        case .toggleOverlay: return "rectangle.3.group.fill"
        case .toggleNHKFloatingWindow: return "newspaper.fill"
        }
    }

    /// The rating ease value (1-4), nil if not a rating action
    public var ratingEase: Int? {
        switch self {
        case .rating1: return 1
        case .rating2: return 2
        case .rating3: return 3
        case .rating4: return 4
        default: return nil
        }
    }
}

// MARK: - Hotkey Binding Model

public struct HotkeyBinding: Codable, Equatable, Sendable {
    public var keyCode: Int      // Carbon virtual key code
    public var modifiers: Int    // Carbon modifier flags (cmdKey|shiftKey|optionKey|controlKey)
    public var isEnabled: Bool

    public static let empty = HotkeyBinding(keyCode: 0, modifiers: 0, isEnabled: false)

    public init(keyCode: Int, modifiers: Int, isEnabled: Bool = true) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }

    /// Whether this binding has a real key set
    public var isValid: Bool {
        keyCode != 0 || modifiers != 0
    }

    /// Human-readable representation of the key combination
    public var displayString: String {
        guard isValid else { return "Not set" }
        var parts: [String] = []
        if modifiers & controlKey != 0 { parts.append("⌃") }
        if modifiers & optionKey != 0  { parts.append("⌥") }
        if modifiers & shiftKey != 0  { parts.append("⇧") }
        if modifiers & cmdKey != 0    { parts.append("⌘") }
        parts.append(keyCodeDisplayName)
        return parts.joined()
    }

    private var keyCodeDisplayName: String {
        switch keyCode {
        case 0x00: return "A"
        case 0x01: return "S"
        case 0x02: return "D"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x05: return "G"
        case 0x06: return "Z"
        case 0x07: return "X"
        case 0x08: return "C"
        case 0x09: return "V"
        case 0x0B: return "B"
        case 0x0C: return "Q"
        case 0x0D: return "W"
        case 0x0E: return "E"
        case 0x0F: return "R"
        case 0x10: return "Y"
        case 0x11: return "T"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x16: return "6"
        case 0x17: return "5"
        case 0x18: return "="
        case 0x19: return "9"
        case 0x1A: return "7"
        case 0x1B: return "-"
        case 0x1C: return "8"
        case 0x1D: return "0"
        case 0x1E: return "]"
        case 0x1F: return "O"
        case 0x20: return "U"
        case 0x21: return "["
        case 0x22: return "I"
        case 0x23: return "P"
        case 0x24: return "Return"
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x27: return "'"
        case 0x28: return "K"
        case 0x29: return ";"
        case 0x2A: return "\\"
        case 0x2B: return ","
        case 0x2C: return "/"
        case 0x2D: return "N"
        case 0x2E: return "M"
        case 0x2F: return "."
        case 0x30: return "Tab"
        case 0x31: return "Space"
        case 0x33: return "Delete"
        case 0x35: return "Esc"
        case 0x36: return "R-Cmd"
        case 0x37: return "L-Cmd"
        case 0x38: return "L-Shift"
        case 0x39: return "Caps Lock"
        case 0x3A: return "L-Option"
        case 0x3B: return "L-Ctrl"
        case 0x3C: return "R-Shift"
        case 0x3D: return "R-Option"
        case 0x3E: return "R-Ctrl"
        case 0x41: return "Keypad ."
        case 0x43: return "Keypad *"
        case 0x45: return "Keypad +"
        case 0x47: return "Keypad Clear"
        case 0x4B: return "Keypad /"
        case 0x4C: return "Keypad Enter"
        case 0x4E: return "Keypad -"
        case 0x50: return "Keypad ="
        case 0x52: return "Keypad 0"
        case 0x53: return "Keypad 1"
        case 0x54: return "Keypad 2"
        case 0x55: return "Keypad 3"
        case 0x56: return "Keypad 4"
        case 0x57: return "Keypad 5"
        case 0x58: return "Keypad 6"
        case 0x59: return "Keypad 7"
        case 0x5B: return "Keypad 8"
        case 0x5C: return "Keypad 9"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x63: return "F3"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x67: return "F11"
        case 0x69: return "F13"
        case 0x6A: return "F16"
        case 0x6B: return "F14"
        case 0x6D: return "F10"
        case 0x6F: return "F12"
        case 0x71: return "F15"
        case 0x72: return "Help/Ins"
        case 0x73: return "Home"
        case 0x74: return "PgUp"
        case 0x75: return "Delete Fwd"
        case 0x76: return "F4"
        case 0x77: return "End"
        case 0x78: return "F2"
        case 0x79: return "PgDn"
        case 0x7A: return "F1"
        case 0x7B: return "Left"
        case 0x7C: return "Right"
        case 0x7D: return "Down"
        case 0x7E: return "Up"
        default:
            // Try to get a readable name from the key code
            if let scalar = UnicodeScalar(keyCode + 0x61) { // 'a' starts at 0x61 in ASCII
                return String(Character(scalar)).uppercased()
            }
            return "Key(\(keyCode))"
        }
    }
}

// MARK: - Global Hotkey Manager

@MainActor
public final class GlobalHotkeyManager: NSObject {
    public static let shared = GlobalHotkeyManager()

    // MARK: - Constants

    private let userDefaultsPrefix = "AnkiHotkey."
    private let eventSignature: UInt32 = 0x414E4B49 // "ANKI" in ASCII

    // MARK: - State

    private var registeredHotKeys: [AnkiHotkeyAction: EventHotKeyRef?] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private var isSetup = false

    // Our stored configurations
    private var bindings: [AnkiHotkeyAction: HotkeyBinding] = [:]

    private override init() {
        super.init()
        loadBindings()
    }

    // MARK: - Setup & Teardown

    /// Called from AppDelegate to register the global event handler
    public func setup() {
        guard !isSetup else {
            // Re-register all hotkeys in case they changed
            registerAll()
            return
        }

        // Install the event handler once
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.globalHotkeyHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        if status != noErr {
            print("GlobalHotkeyManager: Failed to install event handler (error \(status))")
            return
        }

        isSetup = true
        registerAll()
        print("GlobalHotkeyManager: Setup complete with \(bindings.filter { $0.value.isEnabled && $0.value.isValid }.count) active hotkeys")
    }

    public func tearDown() {
        unregisterAll()
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
            eventHandlerRef = nil
        }
        isSetup = false
    }

    // MARK: - Binding Access

    /// Get the current binding for an action
    public func binding(for action: AnkiHotkeyAction) -> HotkeyBinding {
        bindings[action] ?? .empty
    }

    /// Update a binding and persist to UserDefaults
    public func setBinding(_ binding: HotkeyBinding, for action: AnkiHotkeyAction) {
        bindings[action] = binding
        saveBindings()

        // Re-register just this hotkey
        unregister(action: action)
        if binding.isEnabled && binding.isValid {
            register(action: action, binding: binding)
        }
        
        // Refresh menu bar display
        StatusItemManager.shared.refreshGlobalShortcuts()
    }

    /// Toggle enabled state for an action
    public func toggleEnabled(for action: AnkiHotkeyAction) {
        var binding = binding(for: action)
        binding.isEnabled.toggle()
        setBinding(binding, for: action)
    }

    /// Clear a binding (unregister and reset)
    public func clearBinding(for action: AnkiHotkeyAction) {
        unregister(action: action)
        bindings[action] = .empty
        saveBindings()
        StatusItemManager.shared.refreshGlobalShortcuts()
    }

    /// Get all bindings
    public var allBindings: [(action: AnkiHotkeyAction, binding: HotkeyBinding)] {
        AnkiHotkeyAction.allCases.map { ($0, binding(for: $0)) }
    }

    // MARK: - Persistence

    private func loadBindings() {
        let defaults = UserDefaults.standard
        for action in AnkiHotkeyAction.allCases {
            let key = userDefaultsPrefix + "\(action.rawValue)"
            if let data = defaults.data(forKey: key),
               let binding = try? JSONDecoder().decode(HotkeyBinding.self, from: data) {
                bindings[action] = binding
            } else {
                bindings[action] = .empty
            }
        }
    }

    private func saveBindings() {
        let defaults = UserDefaults.standard
        for action in AnkiHotkeyAction.allCases {
            let key = userDefaultsPrefix + "\(action.rawValue)"
            if let binding = bindings[action], binding.isValid {
                if let data = try? JSONEncoder().encode(binding) {
                    defaults.set(data, forKey: key)
                }
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Carbon Registration

    private func registerAll() {
        for action in AnkiHotkeyAction.allCases {
            let binding = binding(for: action)
            if binding.isEnabled && binding.isValid {
                register(action: action, binding: binding)
            }
        }
    }

    private func unregisterAll() {
        for action in AnkiHotkeyAction.allCases {
            unregister(action: action)
        }
    }

    private func register(action: AnkiHotkeyAction, binding: HotkeyBinding) {
        guard binding.isValid else { return }

        // Unregister any existing hotkey for this action first to avoid duplicates
        unregister(action: action)

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: eventSignature, id: UInt32(action.rawValue))

        let status = RegisterEventHotKey(
            UInt32(binding.keyCode),
            UInt32(binding.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            registeredHotKeys[action] = hotKeyRef
        } else {
            print("GlobalHotkeyManager: Failed to register hotkey for \(action.displayName) (error \(status))")
        }
    }

    private func unregister(action: AnkiHotkeyAction) {
        guard let ref = registeredHotKeys[action], let hotKeyRef = ref else { return }
        UnregisterEventHotKey(hotKeyRef)
        registeredHotKeys[action] = nil
    }

    // MARK: - Action Dispatch

    private func executeAction(_ action: AnkiHotkeyAction) {
        guard let state = AppState.shared else { return }

        // For NHK actions, check NHK widget visibility (isHidden or hideFromTouchBar)
        if action == .toggleNHKFloatingWindow {
            let nhkWidget = state.widgets.first { $0.type == .nhkNews }
            guard let nhkWidget, !nhkWidget.isHidden, !nhkWidget.hideFromTouchBar else { return }
            NHKFloatingWindowManager.shared.toggle()
            return
        }

        // Don't execute if all Anki widgets are hidden
        let hasVisibleAnkiWidget = state.widgets.contains { $0.type == .anki && !$0.isHidden }
        guard hasVisibleAnkiWidget else { return }

        switch action {
        case .connect:
            state.ankiState.checkConnection()
        case .reveal:
            state.ankiState.revealAnswer()
        case .sync:
            state.ankiState.syncDecks()
        case .rating1, .rating2, .rating3, .rating4:
            if let ease = action.ratingEase {
                state.ankiState.submitRating(ease: ease)
            }
        case .audio:
            state.ankiState.toggleAudio()
        case .touchBarAudio:
            state.ankiState.toggleTouchBarAudio()
        case .toggleOverlay:
            AnkiFloatingOverlayManager.shared.toggle()
        case .toggleNHKFloatingWindow:
            break // handled above
        }
    }

    // MARK: - Static C Callback

    private static let globalHotkeyHandler: EventHandlerProcPtr = { (_, event, userData) -> OSStatus in
        guard let userData = userData else { return noErr }

        var hotKeyID = EventHotKeyID()
        let err = GetEventParameter(

            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        if err == noErr, hotKeyID.signature == 0x414E4B49 {
            let actionRaw = Int(hotKeyID.id)
            if let action = AnkiHotkeyAction(rawValue: actionRaw) {
                // Dispatch to main actor
                DispatchQueue.main.async {
                    GlobalHotkeyManager.shared.executeAction(action)
                }
            }
        }

        return noErr
    }
}

// MARK: - NSEvent + Hotkey Recording Helpers

extension GlobalHotkeyManager {

    /// Convert NSEvent modifier flags to Carbon modifier flags
    public static func carbonModifiers(from eventModifiers: NSEvent.ModifierFlags) -> Int {
        var carbon: Int = 0
        if eventModifiers.contains(.command)  { carbon |= Int(cmdKey) }
        if eventModifiers.contains(.shift)    { carbon |= Int(shiftKey) }
        if eventModifiers.contains(.option)   { carbon |= Int(optionKey) }
        if eventModifiers.contains(.control)  { carbon |= Int(controlKey) }
        return carbon
    }

    /// Create a HotkeyBinding from an NSEvent (for recording)
    public static func binding(from event: NSEvent) -> HotkeyBinding {
        let keyCode = Int(event.keyCode)
        let modifiers = carbonModifiers(from: event.modifierFlags)
        return HotkeyBinding(keyCode: keyCode, modifiers: modifiers, isEnabled: true)
    }
}
