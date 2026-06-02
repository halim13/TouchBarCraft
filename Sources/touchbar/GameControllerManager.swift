import Foundation
import GameController
import AppKit

// MARK: - UserDefaults Keys

private let udGameControllerEnabled = "AnkiGameControllerEnabled"
private let udGameControllerGamingMode = "AnkiGameControllerGamingMode"

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
        print("GameControllerManager: Controller connected: \(controller.productCategory ?? "Unknown")")
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

    private func mapExtendedButton(_ button: GCControllerButtonInput, on gamepad: GCExtendedGamepad) -> AnkiHotkeyAction? {
        switch button {
        case gamepad.buttonA:
            return .connect
        case gamepad.buttonB:
            return .reveal
        case gamepad.buttonX:
            return .audio
        case gamepad.buttonY:
            return .sync
        case gamepad.leftShoulder:
            return .touchBarAudio
        case gamepad.dpad.up:
            return .rating1  // Again
        case gamepad.dpad.right:
            return .rating2  // Hard
        case gamepad.dpad.down:
            return .rating3  // Good
        case gamepad.dpad.left:
            return .rating4  // Easy
        default:
            return nil
        }
    }

    private func mapMicroButton(_ button: GCControllerButtonInput, on gamepad: GCMicroGamepad) -> AnkiHotkeyAction? {
        // Micro gamepad (Siri Remote, etc.) has fewer buttons
        switch button {
        case gamepad.buttonA:
            return .reveal
        case gamepad.buttonX:
            return .audio
        case gamepad.dpad.up:
            return .rating1
        case gamepad.dpad.right:
            return .rating2
        case gamepad.dpad.down:
            return .rating3
        case gamepad.dpad.left:
            return .rating4
        default:
            return nil
        }
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
    public static var buttonMappingDescription: String {
        """
        A → Connect
        B → Reveal
        X → Toggle Audio
        Y → Sync
        D-pad → Ratings (↑ Again, → Hard, ↓ Good, ← Easy)
        L1 → Toggle Touch Bar Audio
        """
    }
}
