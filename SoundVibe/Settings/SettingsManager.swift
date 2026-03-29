import Foundation
import ServiceManagement

#if canImport(AppKit)
import AppKit
#endif

/// Enum for the microphone trigger mode
enum TriggerMode: String, Codable, CaseIterable {
    case holdToTalk
    case toggle

    var displayName: String {
        switch self {
        case .holdToTalk:
            return "Hold to Talk"
        case .toggle:
            return "Toggle"
        }
    }

    var description: String {
        switch self {
        case .holdToTalk:
            return "Press and hold hotkey to record, release to stop"
        case .toggle:
            return "Press hotkey to start, press again to stop"
        }
    }
}

/// Represents a hotkey combination.
/// Supports both regular keys (with optional modifiers) and modifier-only
/// keys like Right Command. When `isModifierOnly` is true, the hotkey
/// triggers on press/release of the modifier key itself (identified by
/// `keyCode`, e.g. 54 for Right Command).
struct HotkeyCombo: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt32
    /// When true, the hotkey is a lone modifier key (e.g. Right Cmd).
    /// `keyCode` holds the hardware key code of the modifier.
    let isModifierOnly: Bool

    // Well-known modifier key codes
    static let rightCommandKeyCode: UInt16 = 54
    static let leftCommandKeyCode: UInt16 = 55
    static let rightOptionKeyCode: UInt16 = 61
    static let leftOptionKeyCode: UInt16 = 58
    static let rightShiftKeyCode: UInt16 = 60
    static let leftShiftKeyCode: UInt16 = 56
    static let rightControlKeyCode: UInt16 = 62
    static let leftControlKeyCode: UInt16 = 59
    static let fnKeyCode: UInt16 = 63

    /// All key codes that correspond to modifier keys
    static let modifierKeyCodes: Set<UInt16> = [
        54, 55, // Right/Left Command
        61, 58, // Right/Left Option
        60, 56, // Right/Left Shift
        62, 59, // Right/Left Control
        63,     // Fn
    ]

    /// The default hotkey: Right Command (modifier-only)
    static let defaultHotkey = HotkeyCombo(
        keyCode: rightCommandKeyCode,
        modifiers: 0,
        isModifierOnly: true
    )

    init(keyCode: UInt16, modifiers: UInt32 = 0, isModifierOnly: Bool = false) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.isModifierOnly = isModifierOnly
    }

    #if canImport(AppKit)
    /// Creates a HotkeyCombo from a keyboard event.
    /// Detects modifier-only keys automatically.
    init(from event: NSEvent) {
        let code = UInt16(event.keyCode)
        if HotkeyCombo.modifierKeyCodes.contains(code) {
            // User pressed a modifier key alone — record as modifier-only
            self.keyCode = code
            self.modifiers = 0
            self.isModifierOnly = true
        } else {
            self.keyCode = code
            self.modifiers = UInt32(truncatingIfNeeded: event.modifierFlags.rawValue)
            self.isModifierOnly = false
        }
    }

    /// Returns a human-readable description of the hotkey
    var displayString: String {
        if isModifierOnly {
            return modifierKeyName(keyCode)
        }

        var parts: [String] = []
        let flags = UInt(modifiers)
        if flags & NSEvent.ModifierFlags.control.rawValue != 0 {
            parts.append("⌃")
        }
        if flags & NSEvent.ModifierFlags.option.rawValue != 0 {
            parts.append("⌥")
        }
        if flags & NSEvent.ModifierFlags.shift.rawValue != 0 {
            parts.append("⇧")
        }
        if flags & NSEvent.ModifierFlags.command.rawValue != 0 {
            parts.append("⌘")
        }

        let keyName = keyCodeToString(keyCode)
        parts.append(keyName)
        return parts.joined(separator: "")
    }

    /// Human-readable name for a modifier key code
    private func modifierKeyName(_ code: UInt16) -> String {
        switch code {
        case HotkeyCombo.rightCommandKeyCode: return "Right ⌘"
        case HotkeyCombo.leftCommandKeyCode: return "Left ⌘"
        case HotkeyCombo.rightOptionKeyCode: return "Right ⌥"
        case HotkeyCombo.leftOptionKeyCode: return "Left ⌥"
        case HotkeyCombo.rightShiftKeyCode: return "Right ⇧"
        case HotkeyCombo.leftShiftKeyCode: return "Left ⇧"
        case HotkeyCombo.rightControlKeyCode: return "Right ⌃"
        case HotkeyCombo.leftControlKeyCode: return "Left ⌃"
        case HotkeyCombo.fnKeyCode: return "Fn"
        default: return String(format: "Modifier(%d)", code)
        }
    }

    private func keyCodeToString(_ code: UInt16) -> String {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z",
            7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E",
            15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4",
            23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
            27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";",
            39: "'", 43: ",", 47: ".", 44: "/", 49: "Space", 36: "Return",
            48: "Tab", 51: "Delete", 53: "Escape", 10: "§",
            // Arrow keys
            123: "←", 124: "→", 125: "↓", 126: "↑",
            // Function keys
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11",
            111: "F12",
            // Numpad
            82: "Num0", 83: "Num1", 84: "Num2", 85: "Num3", 86: "Num4",
            87: "Num5", 88: "Num6", 89: "Num7", 91: "Num8", 92: "Num9",
            65: "Num.", 67: "Num*", 69: "Num+", 75: "Num/", 78: "Num-",
            76: "NumEnter",
            // Other
            117: "Fwd Del", 115: "Home", 119: "End", 116: "PgUp",
            121: "PgDn",
        ]
        return map[code] ?? String(format: "Key(%d)", code)
    }
    #endif
}

/// Manages all application settings with UserDefaults persistence
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    private let triggerModeKey = "soundvibe.triggerMode"
    private let hotkeyKey = "soundvibe.hotkey"
    private let selectedModelSizeKey = "soundvibe.selectedModelSize"
    private let selectedLanguageKey = "soundvibe.selectedLanguage"
    private let autoLanguageDetectionKey = "soundvibe.autoLanguageDetection"
    private let autoPunctuationKey = "soundvibe.autoPunctuation"
    private let postProcessingEnabledKey = "soundvibe.postProcessingEnabled"
    private let postProcessingModeKey = "soundvibe.postProcessingMode"
    private let customPostProcessingPromptKey = "soundvibe.customPostProcessingPrompt"
    private let launchAtLoginKey = "soundvibe.launchAtLogin"
    private let showFloatingIndicatorKey = "soundvibe.showFloatingIndicator"
    private let clipboardRestoreEnabledKey = "soundvibe.clipboardRestoreEnabled"
    private let pasteDelayKey = "soundvibe.pasteDelay"
    private let silenceTimeoutKey = "soundvibe.silenceTimeout"
    private let selectedInputDeviceKey = "soundvibe.selectedInputDevice"
    private let soundFeedbackEnabledKey = "soundvibe.soundFeedbackEnabled"
    private let typingCooldownEnabledKey = "soundvibe.typingCooldownEnabled"
    private let streamingTranscriptionEnabledKey = "soundvibe.streamingTranscriptionEnabled"
    private let streamingChunkIntervalKey = "soundvibe.streamingChunkInterval"
    private let tailRecordingDelayKey = "soundvibe.tailRecordingDelay"
    private let vadEarlyStopEnabledKey = "soundvibe.vadEarlyStopEnabled"
    private let useStreamingAsFinalKey = "soundvibe.useStreamingAsFinal"
    private let vadTrimEnabledKey = "soundvibe.vadTrimEnabled"
    private let modelKeepAliveEnabledKey = "soundvibe.modelKeepAliveEnabled"

    @Published var triggerMode: TriggerMode = .holdToTalk {
        didSet {
            if let encoded = try? JSONEncoder().encode(triggerMode) {
                defaults.set(encoded, forKey: triggerModeKey)
            }
        }
    }

    @Published var hotkey: HotkeyCombo = HotkeyCombo.defaultHotkey {
        didSet {
            if let encoded = try? JSONEncoder().encode(hotkey) {
                defaults.set(encoded, forKey: hotkeyKey)
            }
        }
    }

    @Published var selectedModelSize: WhisperModelSize = .base {
        didSet {
            defaults.set(selectedModelSize.rawValue, forKey: selectedModelSizeKey)
        }
    }

    @Published var selectedLanguage: String = "en" {
        didSet {
            defaults.set(selectedLanguage, forKey: selectedLanguageKey)
        }
    }

    @Published var autoLanguageDetection: Bool = false {
        didSet {
            defaults.set(autoLanguageDetection, forKey: autoLanguageDetectionKey)
        }
    }

    @Published var autoPunctuation: Bool = true {
        didSet {
            defaults.set(autoPunctuation, forKey: autoPunctuationKey)
        }
    }

    @Published var postProcessingEnabled: Bool = false {
        didSet {
            defaults.set(postProcessingEnabled, forKey: postProcessingEnabledKey)
        }
    }

    @Published var postProcessingMode: PostProcessingMode = .clean {
        didSet {
            defaults.set(postProcessingMode.rawValue, forKey: postProcessingModeKey)
        }
    }

    @Published var customPostProcessingPrompt: String = "" {
        didSet {
            defaults.set(customPostProcessingPrompt, forKey: customPostProcessingPromptKey)
        }
    }

    @Published var launchAtLogin: Bool = false {
        didSet {
            defaults.set(launchAtLogin, forKey: launchAtLoginKey)
            updateLaunchAtLogin()
        }
    }

    @Published var showFloatingIndicator: Bool = true {
        didSet {
            defaults.set(showFloatingIndicator, forKey: showFloatingIndicatorKey)
        }
    }

    @Published var clipboardRestoreEnabled: Bool = true {
        didSet {
            defaults.set(clipboardRestoreEnabled, forKey: clipboardRestoreEnabledKey)
        }
    }

    @Published var pasteDelay: TimeInterval = 0.03 {
        didSet {
            defaults.set(pasteDelay, forKey: pasteDelayKey)
        }
    }

    @Published var silenceTimeout: TimeInterval = 3.0 {
        didSet {
            defaults.set(silenceTimeout, forKey: silenceTimeoutKey)
        }
    }

    @Published var selectedInputDevice: String? {
        didSet {
            defaults.set(selectedInputDevice, forKey: selectedInputDeviceKey)
        }
    }

    @Published var soundFeedbackEnabled: Bool = true {
        didSet {
            defaults.set(soundFeedbackEnabled, forKey: soundFeedbackEnabledKey)
        }
    }

    @Published var typingCooldownEnabled: Bool = true {
        didSet {
            defaults.set(typingCooldownEnabled, forKey: typingCooldownEnabledKey)
        }
    }

    /// Whether to show partial transcription preview in the floating indicator during recording.
    /// Defaults to true on Apple Silicon (arm64), false on Intel (x86_64).
    @Published var streamingTranscriptionEnabled: Bool = {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }() {
        didSet {
            defaults.set(streamingTranscriptionEnabled, forKey: streamingTranscriptionEnabledKey)
        }
    }

    /// How often (in seconds) to run a chunk transcription during recording.
    /// Shorter intervals give faster preview updates at higher CPU cost.
    @Published var streamingChunkInterval: TimeInterval = {
        #if arch(arm64)
        return 2.0
        #else
        return 2.5
        #endif
    }() {
        didSet {
            defaults.set(streamingChunkInterval, forKey: streamingChunkIntervalKey)
        }
    }

    /// Duration to keep recording after hotkey release (tail window).
    /// Lower values reduce latency; VAD early stop can cut this further.
    @Published var tailRecordingDelay: TimeInterval = 0.4 {
        didSet {
            defaults.set(tailRecordingDelay, forKey: tailRecordingDelayKey)
        }
    }

    /// When true, the tail recording window uses VAD to detect silence
    /// and stops early instead of waiting for the full tailRecordingDelay.
    @Published var vadEarlyStopEnabled: Bool = true {
        didSet {
            defaults.set(vadEarlyStopEnabled, forKey: vadEarlyStopEnabledKey)
        }
    }

    /// When true, trim leading and trailing silence from audio before
    /// transcription using VAD-based energy detection. Reduces transcription
    /// time proportionally to the amount of silence removed.
    @Published var vadTrimEnabled: Bool = true {
        didSet {
            defaults.set(vadTrimEnabled, forKey: vadTrimEnabledKey)
        }
    }

    /// When true, periodically run a tiny inference to keep the CoreML/Metal
    /// pipeline warm and avoid cold-start latency after idle periods.
    @Published var modelKeepAliveEnabled: Bool = true {
        didSet {
            defaults.set(modelKeepAliveEnabled, forKey: modelKeepAliveEnabledKey)
        }
    }

    /// When true, use the streaming session's accumulated text as the final
    /// result instead of re-transcribing the full audio from scratch.
    /// Defaults to true on Apple Silicon, false on Intel.
    @Published var useStreamingAsFinal: Bool = {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }() {
        didSet {
            defaults.set(useStreamingAsFinal, forKey: useStreamingAsFinalKey)
        }
    }

    private init() {
        loadSettings()
    }

    /// Allow creating test instances
    init(forTesting: Bool) {
        // Don't load from UserDefaults for testing
    }

    private func loadSettings() {
        // Load triggerMode
        if let data = defaults.data(forKey: triggerModeKey),
           let decoded = try? JSONDecoder().decode(TriggerMode.self, from: data) {
            triggerMode = decoded
        }

        // Load hotkey
        if let data = defaults.data(forKey: hotkeyKey),
           let decoded = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            hotkey = decoded
        }

        // Load selectedModelSize
        if let modelSizeRaw = defaults.string(forKey: selectedModelSizeKey),
           let modelSize = WhisperModelSize(rawValue: modelSizeRaw) {
            selectedModelSize = modelSize
        }

        // Load selectedLanguage
        if let language = defaults.string(forKey: selectedLanguageKey) {
            selectedLanguage = language
        }

        // Load boolean settings
        autoLanguageDetection = defaults.bool(forKey: autoLanguageDetectionKey)
        autoPunctuation = defaults.bool(forKey: autoPunctuationKey)
        postProcessingEnabled = defaults.bool(forKey: postProcessingEnabledKey)
        launchAtLogin = defaults.bool(forKey: launchAtLoginKey)
        syncLaunchAtLoginState()
        showFloatingIndicator = defaults.object(forKey: showFloatingIndicatorKey) == nil ? true : defaults.bool(forKey: showFloatingIndicatorKey)
        clipboardRestoreEnabled = defaults.object(forKey: clipboardRestoreEnabledKey) == nil ? true : defaults.bool(forKey: clipboardRestoreEnabledKey)

        // Load postProcessingMode
        if let modeRaw = defaults.string(forKey: postProcessingModeKey),
           let mode = PostProcessingMode(rawValue: modeRaw) {
            postProcessingMode = mode
        }

        // Load customPostProcessingPrompt
        if let prompt = defaults.string(forKey: customPostProcessingPromptKey) {
            customPostProcessingPrompt = prompt
        }

        // Load time interval settings
        let pasteDelayValue = defaults.double(forKey: pasteDelayKey)
        if pasteDelayValue > 0 {
            pasteDelay = pasteDelayValue
        }

        let silenceTimeoutValue = defaults.double(forKey: silenceTimeoutKey)
        if silenceTimeoutValue > 0 {
            silenceTimeout = silenceTimeoutValue
        }

        // Load selectedInputDevice
        selectedInputDevice = defaults.string(forKey: selectedInputDeviceKey)

        // Load sound feedback (ON by default)
        soundFeedbackEnabled = defaults.object(
            forKey: soundFeedbackEnabledKey
        ) == nil ? true : defaults.bool(forKey: soundFeedbackEnabledKey)

        // Load typing cooldown (ON by default)
        typingCooldownEnabled = defaults.object(
            forKey: typingCooldownEnabledKey
        ) == nil ? true : defaults.bool(forKey: typingCooldownEnabledKey)

        // Load streaming transcription enabled (default: true on arm64, false on x86_64)
        let streamingDefault: Bool = {
            #if arch(arm64)
            return true
            #else
            return false
            #endif
        }()
        streamingTranscriptionEnabled = defaults.object(
            forKey: streamingTranscriptionEnabledKey
        ) == nil ? streamingDefault : defaults.bool(forKey: streamingTranscriptionEnabledKey)

        // Load streaming chunk interval (default: 2.5s)
        let chunkIntervalValue = defaults.double(forKey: streamingChunkIntervalKey)
        if chunkIntervalValue > 0 {
            streamingChunkInterval = chunkIntervalValue
        }

        // Load tail recording delay (default: 0.4s)
        let tailDelayValue = defaults.double(forKey: tailRecordingDelayKey)
        if tailDelayValue > 0 {
            tailRecordingDelay = tailDelayValue
        }

        // Load VAD early stop (ON by default)
        vadEarlyStopEnabled = defaults.object(
            forKey: vadEarlyStopEnabledKey
        ) == nil ? true : defaults.bool(forKey: vadEarlyStopEnabledKey)

        // Load useStreamingAsFinal (default: true on arm64, false on x86_64)
        let streamingAsFinalDefault: Bool = {
            #if arch(arm64)
            return true
            #else
            return false
            #endif
        }()
        useStreamingAsFinal = defaults.object(
            forKey: useStreamingAsFinalKey
        ) == nil ? streamingAsFinalDefault : defaults.bool(forKey: useStreamingAsFinalKey)

        // Load VAD trim enabled (ON by default)
        vadTrimEnabled = defaults.object(
            forKey: vadTrimEnabledKey
        ) == nil ? true : defaults.bool(forKey: vadTrimEnabledKey)

        // Load model keep alive (ON by default)
        modelKeepAliveEnabled = defaults.object(
            forKey: modelKeepAliveEnabledKey
        ) == nil ? true : defaults.bool(forKey: modelKeepAliveEnabledKey)
    }

    /// Resets all settings to their default values
    func resetToDefaults() {
        triggerMode = .holdToTalk
        hotkey = HotkeyCombo.defaultHotkey
        selectedModelSize = .base
        selectedLanguage = "en"
        autoLanguageDetection = false
        autoPunctuation = true
        postProcessingEnabled = false
        postProcessingMode = .clean
        customPostProcessingPrompt = ""
        launchAtLogin = false
        showFloatingIndicator = true
        clipboardRestoreEnabled = true
        pasteDelay = 0.03
        silenceTimeout = 3.0
        selectedInputDevice = nil
        soundFeedbackEnabled = true
        typingCooldownEnabled = true
        streamingTranscriptionEnabled = {
            #if arch(arm64)
            return true
            #else
            return false
            #endif
        }()
        streamingChunkInterval = {
            #if arch(arm64)
            return 2.0
            #else
            return 2.5
            #endif
        }()
        tailRecordingDelay = 0.4
        vadEarlyStopEnabled = true
        useStreamingAsFinal = {
            #if arch(arm64)
            return true
            #else
            return false
            #endif
        }()
        vadTrimEnabled = true
        modelKeepAliveEnabled = true
        let allKeys = [
            triggerModeKey, hotkeyKey, selectedModelSizeKey,
            selectedLanguageKey, autoLanguageDetectionKey,
            autoPunctuationKey, postProcessingEnabledKey,
            postProcessingModeKey, customPostProcessingPromptKey,
            launchAtLoginKey, showFloatingIndicatorKey,
            clipboardRestoreEnabledKey, pasteDelayKey,
            silenceTimeoutKey, selectedInputDeviceKey,
            soundFeedbackEnabledKey, typingCooldownEnabledKey,
            streamingTranscriptionEnabledKey, streamingChunkIntervalKey,
            tailRecordingDelayKey, vadEarlyStopEnabledKey,
            useStreamingAsFinalKey, vadTrimEnabledKey,
            modelKeepAliveEnabledKey,
        ]
        allKeys.forEach { defaults.removeObject(forKey: $0) }
    }

    /// Completely wipes all app data including onboarding status
    func resetAllAppData() {
        resetToDefaults()
        // Reset onboarding flag
        defaults.removeObject(forKey: "SoundVibe_OnboardingCompleted")
        defaults.synchronize()
    }

    /// Exports all settings as JSON data
    func exportSettings() -> Data {
        let settings: [String: Any] = [
            "triggerMode": triggerMode.rawValue,
            "hotkey": ["keyCode": hotkey.keyCode, "modifiers": hotkey.modifiers],
            "selectedModelSize": selectedModelSize.rawValue,
            "selectedLanguage": selectedLanguage,
            "autoLanguageDetection": autoLanguageDetection,
            "autoPunctuation": autoPunctuation,
            "postProcessingEnabled": postProcessingEnabled,
            "postProcessingMode": postProcessingMode.rawValue,
            "customPostProcessingPrompt": customPostProcessingPrompt,
            "launchAtLogin": launchAtLogin,
            "showFloatingIndicator": showFloatingIndicator,
            "clipboardRestoreEnabled": clipboardRestoreEnabled,
            "pasteDelay": pasteDelay,
            "silenceTimeout": silenceTimeout,
            "selectedInputDevice": selectedInputDevice ?? NSNull(),
            "soundFeedbackEnabled": soundFeedbackEnabled,
            "typingCooldownEnabled": typingCooldownEnabled,
            "streamingTranscriptionEnabled": streamingTranscriptionEnabled,
            "streamingChunkInterval": streamingChunkInterval,
            "tailRecordingDelay": tailRecordingDelay,
            "vadEarlyStopEnabled": vadEarlyStopEnabled,
            "useStreamingAsFinal": useStreamingAsFinal,
            "vadTrimEnabled": vadTrimEnabled,
            "modelKeepAliveEnabled": modelKeepAliveEnabled,
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted) {
            return jsonData
        }
        return Data()
    }

    /// Imports settings from JSON data
    func importSettings(_ data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "SettingsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid settings format"])
        }

        if let triggerModeRaw = json["triggerMode"] as? String,
           let mode = TriggerMode(rawValue: triggerModeRaw) {
            triggerMode = mode
        }

        if let hotkeyDict = json["hotkey"] as? [String: Any],
           let keyCode = hotkeyDict["keyCode"] as? UInt16,
           let modifiers = hotkeyDict["modifiers"] as? UInt32 {
            hotkey = HotkeyCombo(keyCode: keyCode, modifiers: modifiers)
        }

        if let modelSizeRaw = json["selectedModelSize"] as? String,
           let modelSize = WhisperModelSize(rawValue: modelSizeRaw) {
            selectedModelSize = modelSize
        }

        if let language = json["selectedLanguage"] as? String {
            selectedLanguage = language
        }

        if let value = json["autoLanguageDetection"] as? Bool {
            autoLanguageDetection = value
        }

        if let value = json["autoPunctuation"] as? Bool {
            autoPunctuation = value
        }

        if let value = json["postProcessingEnabled"] as? Bool {
            postProcessingEnabled = value
        }

        if let modeRaw = json["postProcessingMode"] as? String,
           let mode = PostProcessingMode(rawValue: modeRaw) {
            postProcessingMode = mode
        }

        if let prompt = json["customPostProcessingPrompt"] as? String {
            customPostProcessingPrompt = prompt
        }

        if let value = json["launchAtLogin"] as? Bool {
            launchAtLogin = value
        }

        if let value = json["showFloatingIndicator"] as? Bool {
            showFloatingIndicator = value
        }

        if let value = json["clipboardRestoreEnabled"] as? Bool {
            clipboardRestoreEnabled = value
        }

        if let value = json["pasteDelay"] as? TimeInterval {
            pasteDelay = value
        }

        if let value = json["silenceTimeout"] as? TimeInterval {
            silenceTimeout = value
        }

        if let device = json["selectedInputDevice"],
           !(device is NSNull),
           let deviceUID = device as? String
        {
            selectedInputDevice = deviceUID
        }

        if let value = json["soundFeedbackEnabled"] as? Bool {
            soundFeedbackEnabled = value
        }

        if let value = json["typingCooldownEnabled"] as? Bool {
            typingCooldownEnabled = value
        }

        if let value = json["streamingTranscriptionEnabled"] as? Bool {
            streamingTranscriptionEnabled = value
        }

        if let value = json["streamingChunkInterval"] as? TimeInterval {
            streamingChunkInterval = value
        }

        if let value = json["tailRecordingDelay"] as? TimeInterval {
            tailRecordingDelay = value
        }

        if let value = json["vadEarlyStopEnabled"] as? Bool {
            vadEarlyStopEnabled = value
        }

        if let value = json["useStreamingAsFinal"] as? Bool {
            useStreamingAsFinal = value
        }

        if let value = json["vadTrimEnabled"] as? Bool {
            vadTrimEnabled = value
        }

        if let value = json["modelKeepAliveEnabled"] as? Bool {
            modelKeepAliveEnabled = value
        }
    }

    private func updateLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print(
                "Failed to \(launchAtLogin ? "enable" : "disable") launch at login: \(error)"
            )
        }
    }

    /// Sync our stored setting with the actual system login item state.
    /// The user may have toggled it off in System Settings > General > Login Items.
    private func syncLaunchAtLoginState() {
        let status = SMAppService.mainApp.status
        let isRegistered = (status == .enabled)
        if launchAtLogin != isRegistered {
            launchAtLogin = isRegistered
        }
    }
}
