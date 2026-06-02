import Foundation
import GameController
import AppKit

// MARK: - UserDefaults Keys

private let udGameControllerEnabled = "AnkiGameControllerEnabled"
private let udGameControllerGamingMode = "AnkiGameControllerGamingMode"
private let udGameControllerMappingPrefix = "GameControllerMapping_"

// MARK: - Game Controller Button Enum

/// Physical buttons available on an extended gamepad.
public enum GameControllerButton: String, Codable, CaseIterable, Sendable {
    case buttonA = "A"
    case buttonB = "B"
    case buttonX = "X"
    case buttonY = "Y"
    case leftShoulder = "L1"
    case dpadUp = "D-Pad ↑"
    case dpadRight = "D-Pad →"
    case dpadDown = "D-Pad ↓"
    case dpadLeft = "D-Pad ←"
    
    /// Buttons available on micro gamepad (Siri Remote, etc.)
    public static let microButtons: Set<GameControllerButton> = [.buttonA, .buttonX, .dpadUp, .dpadRight, .dpadDown, .dpadLeft]
    
    /// SF Symbol icon name for display
    public var iconName: String {
        switch self {
        case .buttonA: return "a.circle.fill"
        case .buttonB: return "b.circle.fill"
        case .buttonX: return "x.circle.fill"
        case .buttonY: return "y.circle.fill"
        case .leftShoulder: return "l.rectangle.roundedbottom.fill"
        case .dpadUp: return "arrowtriangle.up.fill"
        case .dpadRight: return "arrowtriangle.right.fill"
        case .dpadDown: return "arrowtriangle.down.fill"
        case .dpadLeft: return "arrowtriangle.left.fill"
        }
    }
}

// MARK: - UserDefaults Helpers

private extension GameControllerManager {
    func saveMapping(for button: GameControllerButton, action: AnkiHotkeyAction?) {
        let key = udGameControllerMappingPrefix + button.rawValue
        if let action = action {
            UserDefaults.standard.set(action.rawValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    func loadMapping(for button: GameControllerButton) -> AnkiHotkeyAction? {
        let key = udGameControllerMappingPrefix + button.rawValue
        guard let rawValue = UserDefaults.standard.object(forKey: key) as? Int else {
            return nil
        }
        return AnkiHotkeyAction(rawValue: rawValue)
    }
    
    /// Get the mapped action for a button, falling back to default if none saved.
    func actionForButton(_ button: GameControllerButton) -> AnkiHotkeyAction? {
        if let saved = loadMapping(for: button) {
            return saved
        }
        // Fall back to default mapping
        return Self.defaultMapping[button] ?? nil
    }
    
    /// Build a mapping description string for the settings UI.
    func buildMappingDescription() -> String {
        return GameControllerButton.allCases.compactMap { button -> String? in
            // Hide micro-only buttons from extended description? No, show all.
            guard let action = actionForButton(button) else { return nil }
            let actionName = action.displayName
            // Pad button names for alignment
            let padded = button.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
            return "\(padded) → \(actionName)"
        }.joined(separator: "\n")
    }
    
    private static let defaultMapping: [GameControllerButton: AnkiHotkeyAction] = [
        // Extended gamepad (Xbox, PS, etc.)
        .buttonA: .connect,
        .buttonB: .reveal,
        .buttonX: .audio,
        .buttonY: .sync,
        .leftShoulder: .touchBarAudio,
        .dpadUp: .rating1,
        .dpadRight: .rating2,
        .dpadDown: .rating3,
        .dpadLeft: .rating4,
    ]
    
}

// MARK: - Game Controller Manager

// MARK: - Game Controller Manager

/// Manages game controller / joystick input and maps it to the same Anki hotkey actions
/// that `GlobalHotkeyManager` provides via keyboard shortcuts.
@MainActor
public final class GameControllerManager: NSObject {

    public static let shared = GameControllerManager()

    // MARK: - Settings

    /// Master toggle: enable/disable game controller input for Anki entirely.
    public var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: udGameControllerEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: udGameControllerEnabled)
            if newValue {
                startMonitoring()
            } else {
                stopMonitoring()
            }
            refreshMenu()
        }
    }

    /// Gaming mode: when ON, all game controller inputs for Anki are suppressed
    /// so real games are not affected.
    public var isGamingMode: Bool {
        get { UserDefaults.standard.bool(forKey: udGameControllerGamingMode) }
        set {
            UserDefaults.standard.set(newValue, forKey: udGameControllerGamingMode)
            refreshMenu()
        }
    }

    // MARK: - State

    /// Whether Anki input processing is currently active (both enabled AND not in gaming mode).
    public var isProcessingActive: Bool {
        isEnabled && !isGamingMode
    }

    /// Currently connected controllers (for display purposes)
    public private(set) var connectedControllers: [String] = []

    /// Whether at least one controller is connected.
    public var hasConnectedController: Bool {
        !connectedControllers.isEmpty
    }

    /// String describing connected controllers (e.g. "🎮 Xbox Wireless Controller")
    public var controllerStatusString: String {
        if connectedControllers.isEmpty {
            return "No controller connected"
        }
        return "🎮 " + connectedControllers.joined(separator: ", ")
    }

    /// Timestamp-based debounce to prevent double-fires from analog-to-digital transitions.
    private var lastInputTimes: [String: CFTimeInterval] = [:]
    private let debounceInterval: CFTimeInterval = 0.25

    // MARK: - Init

    private override init() {
        super.init()
        // Restore persisted state
        if UserDefaults.standard.object(forKey: udGameControllerEnabled) == nil {
            // Default to enabled
            UserDefaults.standard.set(true, forKey: udGameControllerEnabled)
        }
        if UserDefaults.standard.object(forKey: udGameControllerGamingMode) == nil {
            // Default to not gaming
            UserDefaults.standard.set(false, forKey: udGameControllerGamingMode)
        }

        if isEnabled {
            // Start monitoring after a short delay to let app finish launching
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startMonitoring()
            }
        }
    }

    // MARK: - Monitoring

    public func startMonitoring() {
        // Register for connect/disconnect notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        // Set up already-connected controllers
        for controller in GCController.controllers() {
            setupController(controller)
        }

        updateConnectedControllers()
        refreshMenu()
        print("GameControllerManager: Started monitoring for game controllers (enabled=\(isEnabled), gamingMode=\(isGamingMode))")
    }

    public func stopMonitoring() {
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidDisconnect, object: nil)

        // Remove handlers from all controllers
        for controller in GCController.controllers() {
            controller.extendedGamepad?.valueChangedHandler = nil
        }

        connectedControllers = []
        refreshMenu()
        print("GameControllerManager: Stopped monitoring for game controllers")
    }

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        setupController(controller)
        updateConnectedControllers()
        refreshMenu()
        print("GameControllerManager: Controller connected: \(controller.productCategory)")
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        updateConnectedControllers()
        refreshMenu()
        print("GameControllerManager: Controller disconnected")
    }

    // MARK: - Controller Setup

    private func setupController(_ controller: GCController) {
        guard let extendedGamepad = controller.extendedGamepad else {
            // Could also support microGamepad for remote-type controllers
            if let microGamepad = controller.microGamepad {
                microGamepad.valueChangedHandler = { [weak self] (gamepad, element) in
                    self?.handleMicroInput(gamepad, element: element)
                }
            }
            return
        }

        extendedGamepad.valueChangedHandler = { [weak self] (gamepad, element) in
            self?.handleExtendedInput(gamepad, element: element)
        }
    }

    // MARK: - Input Handling — Extended Gamepad (Xbox, PS, etc.)

    private func handleExtendedInput(_ gamepad: GCExtendedGamepad, element: GCControllerElement) {
        guard isProcessingActive else { return }

        // Only respond to button presses (not releases)
        guard let button = element as? GCControllerButtonInput, button.isPressed else { return }

        let action = mapExtendedButton(button, on: gamepad)
        guard let action = action else { return }

        // Debounce
        let key = "extended_\(action.rawValue)"
        let now = CACurrentMediaTime()
        if let last = lastInputTimes[key], now - last < debounceInterval {
            return
        }
        lastInputTimes[key] = now

        executeAnkiAction(action)
    }

    private func handleMicroInput(_ gamepad: GCMicroGamepad, element: GCControllerElement) {
        guard isProcessingActive else { return }

        if let button = element as? GCControllerButtonInput, button.isPressed {
            let action = mapMicroButton(button, on: gamepad)
            guard let action = action else { return }

            let key = "micro_\(action.rawValue)"
            let now = CACurrentMediaTime()
            if let last = lastInputTimes[key], now - last < debounceInterval {
                return
            }
            lastInputTimes[key] = now

            executeAnkiAction(action)
        }
    }

    // MARK: - Button Mapping

    /// Convert a GCControllerButtonInput to our GameControllerButton enum.
    private func identifyExtendedButton(_ button: GCControllerButtonInput, on gamepad: GCExtendedGamepad) -> GameControllerButton? {
        switch button {
        case gamepad.buttonA: return .buttonA
        case gamepad.buttonB: return .buttonB
        case gamepad.buttonX: return .buttonX
        case gamepad.buttonY: return .buttonY
        case gamepad.leftShoulder: return .leftShoulder
        case gamepad.dpad.up: return .dpadUp
        case gamepad.dpad.right: return .dpadRight
        case gamepad.dpad.down: return .dpadDown
        case gamepad.dpad.left: return .dpadLeft
        default: return nil
        }
    }
    
    private func identifyMicroButton(_ button: GCControllerButtonInput, on gamepad: GCMicroGamepad) -> GameControllerButton? {
        switch button {
        case gamepad.buttonA: return .buttonA
        case gamepad.buttonX: return .buttonX
        case gamepad.dpad.up: return .dpadUp
        case gamepad.dpad.right: return .dpadRight
        case gamepad.dpad.down: return .dpadDown
        case gamepad.dpad.left: return .dpadLeft
        default: return nil
        }
    }
    
    private func mapExtendedButton(_ button: GCControllerButtonInput, on gamepad: GCExtendedGamepad) -> AnkiHotkeyAction? {
        guard let identified = identifyExtendedButton(button, on: gamepad) else { return nil }
        return actionForButton(identified)
    }

    private func mapMicroButton(_ button: GCControllerButtonInput, on gamepad: GCMicroGamepad) -> AnkiHotkeyAction? {
        guard let identified = identifyMicroButton(button, on: gamepad) else { return nil }
        return actionForButton(identified)
    }

    // MARK: - Action Dispatch

    private func executeAnkiAction(_ action: AnkiHotkeyAction) {
        guard let state = AppState.shared else { return }

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
        }
    }

    // MARK: - Controller List

    private func updateConnectedControllers() {
        let controllers = GCController.controllers()
        connectedControllers = controllers.compactMap { $0.productCategory }
    }

    // MARK: - Menu Refresh

    private func refreshMenu() {
        StatusItemManager.shared.refreshGameControllerStatus()
    }

    // MARK: - Settings Display

    /// Human-readable button mapping description for the settings UI.
    public var buttonMappingDescription: String {
        buildMappingDescription()
    }
    
    // MARK: - Public Mapping API
    
    /// Set the mapping for a given button and persist to UserDefaults.
    public func setMapping(for button: GameControllerButton, action: AnkiHotkeyAction?) {
        saveMapping(for: button, action: action)
    }
    
    /// Load a saved mapping for a given button (if any), or nil if using default.
    public func loadedAction(for button: GameControllerButton) -> AnkiHotkeyAction? {
        loadMapping(for: button)
    }
    
    /// Get the default action for a controller button.
    public static func defaultAction(for button: GameControllerButton) -> AnkiHotkeyAction? {
        defaultMapping[button]
    }
}
