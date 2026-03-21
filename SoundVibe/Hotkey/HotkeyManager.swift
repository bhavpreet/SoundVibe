import Foundation

// MARK: - Protocols and Types (cross-platform)

protocol HotkeyManagerDelegate: AnyObject, Sendable {
    func hotkeyPressed()
    func hotkeyReleased()
}

enum HotkeyError: LocalizedError {
    case accessibilityPermissionDenied
    case eventTapCreationFailed
    case conflict

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission denied. "
                + "Please enable in System Settings > "
                + "Privacy & Security."
        case .eventTapCreationFailed:
            return "Failed to create global event tap."
        case .conflict:
            return "Hotkey conflicts with another application."
        }
    }
}

#if os(macOS)
import AppKit
import Quartz

/// Manages global hotkey registration using Quartz Event Services
/// (CGEvent tap).
///
/// **Threading**: This is deliberately NOT an actor. The CGEvent tap
/// callback must run synchronously on the main run loop. Using an
/// actor would force the callback onto a cooperative thread pool,
/// causing the run loop source to never deliver events.
///
/// All public methods must be called from `@MainActor` (the main
/// thread), which is also where the CGEvent tap run loop source
/// lives.
@MainActor
final class HotkeyManager {

    // MARK: - Properties

    // fileprivate so the C callback can re-enable a disabled tap
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private(set) var isEnabled = false
    private(set) var currentHotkey: HotkeyCombo
    private(set) var triggerMode: TriggerMode
    weak var delegate: HotkeyManagerDelegate?

    /// Tracks toggle state (for toggle trigger mode)
    private var toggleIsActive = false
    /// Tracks whether the modifier-only key is currently held down
    private var modifierKeyIsDown = false

    // MARK: - Typing Cooldown (A7)

    /// Timestamp of last non-hotkey keypress
    private var lastKeypressTime: Date?

    /// Cooldown duration in seconds
    private let typingCooldownDuration: TimeInterval = 0.4

    // MARK: - Initialization

    init(
        hotkey: HotkeyCombo = HotkeyCombo.defaultHotkey,
        triggerMode: TriggerMode = .holdToTalk
    ) {
        self.currentHotkey = hotkey
        self.triggerMode = triggerMode
    }

    // MARK: - Public Methods

    /// Starts global hotkey listening. Requires accessibility
    /// permission. Must be called on the main thread.
    func start() throws {
        guard !isEnabled else { return }

        guard AXIsProcessTrusted() else {
            throw HotkeyError.accessibilityPermissionDenied
        }

        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )

        // Store `self` in an Unmanaged pointer so the C callback
        // can reach back into Swift.
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyEventCallback,
            userInfo: refcon
        ) else {
            throw HotkeyError.eventTapCreationFailed
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault, tap, 0
        )
        self.runLoopSource = source

        // Attach to the MAIN run loop so events are delivered on
        // the main thread where we can safely access our state.
        CFRunLoopAddSource(
            CFRunLoopGetMain(), source, .commonModes
        )
        CGEvent.tapEnable(tap: tap, enable: true)

        isEnabled = true
    }

    /// Stops global hotkey listening.
    func stop() {
        guard isEnabled else { return }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(), source, .commonModes
            )
            self.runLoopSource = nil
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            self.eventTap = nil
        }

        isEnabled = false
    }

    /// Updates the hotkey combination.
    func updateHotkey(_ combo: HotkeyCombo) {
        currentHotkey = combo
        // Reset state when hotkey changes
        modifierKeyIsDown = false
        toggleIsActive = false
    }

    /// Updates the trigger mode (hold-to-talk vs toggle).
    func updateTriggerMode(_ mode: TriggerMode) {
        triggerMode = mode
        toggleIsActive = false
        modifierKeyIsDown = false
    }

    /// A7: Checks if hotkey should be blocked due to recent typing.
    /// Only applies to hold-to-talk mode.
    func isBlockedByTypingCooldown() -> Bool {
        guard let lastPress = lastKeypressTime else {
            return false
        }
        let elapsed = Date().timeIntervalSince(lastPress)
        return elapsed < typingCooldownDuration
    }

    // MARK: - Event Processing (called from C callback on main thread)

    /// Process a raw CGEvent. Called synchronously on the main
    /// thread from the CGEvent tap callback.
    fileprivate func processEvent(
        type: CGEventType,
        event: CGEvent
    ) {
        let keyCode = UInt16(
            event.getIntegerValueField(.keyboardEventKeycode)
        )

        // A7: Track non-hotkey keypresses for typing cooldown
        if type == .keyDown {
            let isHotkeyKey: Bool
            if currentHotkey.isModifierOnly {
                isHotkeyKey = false // modifier-only uses flagsChanged
            } else {
                isHotkeyKey = keyCode == currentHotkey.keyCode
            }
            if !isHotkeyKey {
                lastKeypressTime = Date()
            }
        }

        if currentHotkey.isModifierOnly {
            processModifierOnlyEvent(
                type: type,
                keyCode: keyCode,
                flags: event.flags
            )
        } else {
            processRegularKeyEvent(
                type: type,
                keyCode: keyCode,
                flags: event.flags
            )
        }
    }

    // MARK: - Regular Key Hotkey (e.g. ⌥D, ⌘;)

    private func processRegularKeyEvent(
        type: CGEventType,
        keyCode: UInt16,
        flags: CGEventFlags
    ) {
        guard type == .keyDown || type == .keyUp else { return }
        guard keyCode == currentHotkey.keyCode else { return }

        let requiredModifiers = CGEventFlags(
            rawValue: UInt64(currentHotkey.modifiers)
        )
        let eventModifiers = flags.intersection([
            .maskShift, .maskControl, .maskAlternate, .maskCommand,
        ])
        guard eventModifiers == requiredModifiers else { return }

        switch type {
        case .keyDown:
            fireHotkeyDown()
        case .keyUp:
            fireHotkeyUp()
        default:
            break
        }
    }

    // MARK: - Modifier-Only Hotkey (e.g. Right ⌘)

    private func processModifierOnlyEvent(
        type: CGEventType,
        keyCode: UInt16,
        flags: CGEventFlags
    ) {
        guard type == .flagsChanged else { return }
        guard keyCode == currentHotkey.keyCode else { return }

        let isPressed = modifierFlagIsSet(
            for: currentHotkey.keyCode,
            in: flags
        )

        if isPressed && !modifierKeyIsDown {
            modifierKeyIsDown = true
            fireHotkeyDown()
        } else if !isPressed && modifierKeyIsDown {
            modifierKeyIsDown = false
            fireHotkeyUp()
        }
    }

    private func modifierFlagIsSet(
        for keyCode: UInt16,
        in flags: CGEventFlags
    ) -> Bool {
        switch keyCode {
        case HotkeyCombo.rightCommandKeyCode,
             HotkeyCombo.leftCommandKeyCode:
            return flags.contains(.maskCommand)
        case HotkeyCombo.rightOptionKeyCode,
             HotkeyCombo.leftOptionKeyCode:
            return flags.contains(.maskAlternate)
        case HotkeyCombo.rightShiftKeyCode,
             HotkeyCombo.leftShiftKeyCode:
            return flags.contains(.maskShift)
        case HotkeyCombo.rightControlKeyCode,
             HotkeyCombo.leftControlKeyCode:
            return flags.contains(.maskControl)
        default:
            return false
        }
    }

    // MARK: - Delegate Dispatch

    private func fireHotkeyDown() {
        guard let delegate = delegate else { return }

        switch triggerMode {
        case .holdToTalk:
            delegate.hotkeyPressed()

        case .toggle:
            if !toggleIsActive {
                toggleIsActive = true
                delegate.hotkeyPressed()
            } else {
                toggleIsActive = false
                delegate.hotkeyReleased()
            }
        }
    }

    private func fireHotkeyUp() {
        guard triggerMode == .holdToTalk else { return }
        guard let delegate = delegate else { return }

        delegate.hotkeyReleased()
    }
}

// MARK: - CGEvent Tap C Callback (free function)

/// Free function required by CGEvent.tapCreate. Runs on the main
/// run loop thread (because we attached the source to
/// `CFRunLoopGetMain`). We use `MainActor.assumeIsolated` to tell
/// Swift this is safe.
private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }

    MainActor.assumeIsolated {
        let manager = Unmanaged<HotkeyManager>
            .fromOpaque(refcon).takeUnretainedValue()

        // Re-enable the tap if macOS disabled it (happens when the
        // system thinks the tap is unresponsive).
        if type == .tapDisabledByTimeout
            || type == .tapDisabledByUserInput
        {
            if let tap = manager.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        manager.processEvent(type: type, event: event)
    }

    return Unmanaged.passUnretained(event)
}

#endif
