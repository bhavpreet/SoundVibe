import XCTest
@testable import SoundVibe

#if os(macOS)
import AppKit

/// Tests for onboarding-related logic that can run without launching the full app.
/// These test the data flow, settings persistence, and validation logic
/// extracted from the onboarding UI.
final class OnboardingLogicTests: XCTestCase {

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Clear onboarding state before each test
        UserDefaults.standard.removeObject(forKey: "SoundVibe_OnboardingCompleted")
        UserDefaults.standard.removeObject(forKey: "SoundVibe_HotkeyCombo")
        UserDefaults.standard.removeObject(forKey: "SoundVibe_SelectedLanguage")
        UserDefaults.standard.removeObject(forKey: "SoundVibe_TriggerMode")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "SoundVibe_OnboardingCompleted")
        UserDefaults.standard.removeObject(forKey: "SoundVibe_HotkeyCombo")
        UserDefaults.standard.removeObject(forKey: "SoundVibe_SelectedLanguage")
        UserDefaults.standard.removeObject(forKey: "SoundVibe_TriggerMode")
        super.tearDown()
    }

    // MARK: - HotkeyCombo Tests

    func testHotkeyComboDefaultIsRightCommand() {
        let combo = HotkeyCombo.defaultHotkey
        XCTAssertEqual(
            combo.keyCode,
            HotkeyCombo.rightCommandKeyCode,
            "Default should be Right Command (keyCode 54)"
        )
        XCTAssertTrue(
            combo.isModifierOnly,
            "Default should be modifier-only"
        )
        XCTAssertEqual(combo.modifiers, 0, "Modifier-only combos have no separate modifiers")
    }

    func testHotkeyComboEquality() {
        let combo1 = HotkeyCombo(keyCode: 54, modifiers: 0, isModifierOnly: true)
        let combo2 = HotkeyCombo(keyCode: 54, modifiers: 0, isModifierOnly: true)
        let combo3 = HotkeyCombo(keyCode: 55, modifiers: 0, isModifierOnly: true)
        let combo4 = HotkeyCombo(keyCode: 54, modifiers: 0, isModifierOnly: false)

        XCTAssertEqual(combo1, combo2, "Identical combos should be equal")
        XCTAssertNotEqual(combo1, combo3, "Different key codes should not be equal")
        XCTAssertNotEqual(combo1, combo4, "Different isModifierOnly should not be equal")
    }

    func testHotkeyComboEncodingRegularKey() throws {
        let combo = HotkeyCombo(keyCode: 2, modifiers: 0x80000)
        let data = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(HotkeyCombo.self, from: data)

        XCTAssertEqual(decoded.keyCode, 2)
        XCTAssertEqual(decoded.modifiers, 0x80000)
        XCTAssertFalse(decoded.isModifierOnly)
    }

    func testHotkeyComboEncodingModifierOnly() throws {
        let combo = HotkeyCombo(
            keyCode: HotkeyCombo.rightCommandKeyCode,
            modifiers: 0,
            isModifierOnly: true
        )
        let data = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(HotkeyCombo.self, from: data)

        XCTAssertEqual(decoded.keyCode, 54)
        XCTAssertTrue(decoded.isModifierOnly)
    }

    func testHotkeyComboDisplayStringModifierOnly() {
        let cases: [(UInt16, String)] = [
            (HotkeyCombo.rightCommandKeyCode, "Right ⌘"),
            (HotkeyCombo.leftCommandKeyCode, "Left ⌘"),
            (HotkeyCombo.rightOptionKeyCode, "Right ⌥"),
            (HotkeyCombo.leftOptionKeyCode, "Left ⌥"),
            (HotkeyCombo.rightShiftKeyCode, "Right ⇧"),
            (HotkeyCombo.leftShiftKeyCode, "Left ⇧"),
            (HotkeyCombo.rightControlKeyCode, "Right ⌃"),
            (HotkeyCombo.leftControlKeyCode, "Left ⌃"),
            (HotkeyCombo.fnKeyCode, "Fn"),
        ]

        for (keyCode, expected) in cases {
            let combo = HotkeyCombo(
                keyCode: keyCode,
                modifiers: 0,
                isModifierOnly: true
            )
            XCTAssertEqual(
                combo.displayString,
                expected,
                "KeyCode \(keyCode) should display as '\(expected)'"
            )
        }
    }

    func testHotkeyComboDisplayStringWithOptionModifier() {
        let combo = HotkeyCombo(
            keyCode: 2,
            modifiers: UInt32(NSEvent.ModifierFlags.option.rawValue)
        )
        let display = combo.displayString
        XCTAssertTrue(display.contains("⌥"), "Should contain ⌥ for option modifier")
        XCTAssertTrue(display.contains("D"), "KeyCode 2 should map to 'D'")
    }

    func testHotkeyComboDisplayStringWithCommandModifier() {
        let combo = HotkeyCombo(
            keyCode: 41,
            modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue)
        )
        let display = combo.displayString
        XCTAssertTrue(display.contains("⌘"), "Should contain ⌘ for command modifier")
        XCTAssertTrue(display.contains(";"), "KeyCode 41 should map to ';'")
    }

    func testHotkeyComboDisplayStringWithMultipleModifiers() {
        let mods = UInt32(
            NSEvent.ModifierFlags.command.rawValue |
            NSEvent.ModifierFlags.shift.rawValue
        )
        let combo = HotkeyCombo(keyCode: 9, modifiers: mods)
        let display = combo.displayString
        XCTAssertTrue(display.contains("⌘"), "Should contain ⌘")
        XCTAssertTrue(display.contains("⇧"), "Should contain ⇧")
        XCTAssertTrue(display.contains("V"), "KeyCode 9 should map to 'V'")
    }

    func testHotkeyComboDisplayStringNoModifiers() {
        let combo = HotkeyCombo(keyCode: 49, modifiers: 0)
        let display = combo.displayString
        XCTAssertEqual(display, "Space", "Space with no modifiers")
    }

    func testHotkeyComboKeyCodeMapping() {
        let testCases: [(UInt16, String)] = [
            (0, "A"), (1, "S"), (2, "D"), (3, "F"),
            (12, "Q"), (13, "W"), (14, "E"), (15, "R"),
            (49, "Space"), (36, "Return"), (48, "Tab"),
            (53, "Escape"),
            (122, "F1"), (120, "F2"),
        ]

        for (keyCode, expectedName) in testCases {
            let combo = HotkeyCombo(keyCode: keyCode, modifiers: 0)
            XCTAssertTrue(
                combo.displayString.contains(expectedName),
                "KeyCode \(keyCode) should display as '\(expectedName)', got '\(combo.displayString)'"
            )
        }
    }

    func testModifierKeyCodesSetIsComplete() {
        // All modifier key codes should be in the set
        let expected: [UInt16] = [54, 55, 61, 58, 60, 56, 62, 59, 63]
        for code in expected {
            XCTAssertTrue(
                HotkeyCombo.modifierKeyCodes.contains(code),
                "modifierKeyCodes should contain \(code)"
            )
        }
        XCTAssertEqual(
            HotkeyCombo.modifierKeyCodes.count,
            expected.count,
            "Should have exactly \(expected.count) modifier key codes"
        )
    }

    func testRegularKeyIsNotModifierOnly() {
        let combo = HotkeyCombo(keyCode: 2, modifiers: 0x80000)
        XCTAssertFalse(combo.isModifierOnly)
    }

    // MARK: - Onboarding Step Validation Tests

    func testOnboardingStepValidationWelcomeAlwaysProceeds() {
        // Step 0 (Welcome) should always allow proceeding
        let canProceed = onboardingCanProceed(
            step: 0,
            micGranted: false,
            accessibilityGranted: false,
            hotkeySet: false
        )
        XCTAssertTrue(canProceed, "Welcome step should always allow proceeding")
    }

    func testOnboardingStepValidationMicRequired() {
        let canProceedNo = onboardingCanProceed(
            step: 1,
            micGranted: false,
            accessibilityGranted: false,
            hotkeySet: false
        )
        XCTAssertFalse(canProceedNo, "Mic step should block without permission")

        let canProceedYes = onboardingCanProceed(
            step: 1,
            micGranted: true,
            accessibilityGranted: false,
            hotkeySet: false
        )
        XCTAssertTrue(canProceedYes, "Mic step should allow with permission")
    }

    func testOnboardingStepValidationAccessibilityRequired() {
        let canProceedNo = onboardingCanProceed(
            step: 2,
            micGranted: true,
            accessibilityGranted: false,
            hotkeySet: false
        )
        XCTAssertFalse(canProceedNo, "Accessibility step should block without permission")

        let canProceedYes = onboardingCanProceed(
            step: 2,
            micGranted: true,
            accessibilityGranted: true,
            hotkeySet: false
        )
        XCTAssertTrue(canProceedYes, "Accessibility step should allow with permission")
    }

    func testOnboardingStepValidationHotkeyRequired() {
        let canProceedNo = onboardingCanProceed(
            step: 3,
            micGranted: true,
            accessibilityGranted: true,
            hotkeySet: false
        )
        XCTAssertFalse(canProceedNo, "Hotkey step should block without hotkey set")

        let canProceedYes = onboardingCanProceed(
            step: 3,
            micGranted: true,
            accessibilityGranted: true,
            hotkeySet: true
        )
        XCTAssertTrue(canProceedYes, "Hotkey step should allow with hotkey set")
    }

    func testOnboardingStepValidationLanguageAlwaysProceeds() {
        let canProceed = onboardingCanProceed(
            step: 4,
            micGranted: true,
            accessibilityGranted: true,
            hotkeySet: true
        )
        XCTAssertTrue(canProceed, "Language step should always allow proceeding")
    }

    // MARK: - Settings Persistence from Onboarding

    func testOnboardingCompletionFlagPersists() {
        XCTAssertFalse(
            UserDefaults.standard.bool(forKey: "SoundVibe_OnboardingCompleted"),
            "Should not be completed initially"
        )

        UserDefaults.standard.set(true, forKey: "SoundVibe_OnboardingCompleted")
        XCTAssertTrue(
            UserDefaults.standard.bool(forKey: "SoundVibe_OnboardingCompleted"),
            "Should persist completion flag"
        )
    }

    func testHotkeyPersistsThroughSettingsManager() {
        let settings = SettingsManager(forTesting: true)

        // Test regular key combo
        let regularCombo = HotkeyCombo(
            keyCode: 2,
            modifiers: UInt32(NSEvent.ModifierFlags.option.rawValue)
        )
        settings.hotkey = regularCombo
        XCTAssertEqual(settings.hotkey.keyCode, 2)
        XCTAssertFalse(settings.hotkey.isModifierOnly)

        // Test modifier-only combo
        let modCombo = HotkeyCombo(
            keyCode: HotkeyCombo.rightCommandKeyCode,
            modifiers: 0,
            isModifierOnly: true
        )
        settings.hotkey = modCombo
        XCTAssertEqual(settings.hotkey.keyCode, 54)
        XCTAssertTrue(settings.hotkey.isModifierOnly)
    }

    func testTriggerModePersistsThroughSettingsManager() {
        let settings = SettingsManager(forTesting: true)

        settings.triggerMode = .toggle
        XCTAssertEqual(settings.triggerMode, .toggle, "Toggle mode should persist")

        settings.triggerMode = .holdToTalk
        XCTAssertEqual(settings.triggerMode, .holdToTalk, "Hold-to-talk mode should persist")
    }

    func testLanguagePersistsThroughSettingsManager() {
        let settings = SettingsManager(forTesting: true)

        settings.selectedLanguage = "fr"
        XCTAssertEqual(settings.selectedLanguage, "fr", "French should persist")

        settings.selectedLanguage = "de"
        XCTAssertEqual(settings.selectedLanguage, "de", "German should persist")
    }

    // MARK: - TriggerMode Tests

    func testTriggerModeRawValues() {
        XCTAssertEqual(TriggerMode.holdToTalk.rawValue, "holdToTalk")
        XCTAssertEqual(TriggerMode.toggle.rawValue, "toggle")
    }

    func testTriggerModeDisplayName() {
        XCTAssertEqual(TriggerMode.holdToTalk.displayName, "Hold to Talk")
        XCTAssertEqual(TriggerMode.toggle.displayName, "Toggle")
    }

    func testTriggerModeCodable() throws {
        let original = TriggerMode.toggle
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TriggerMode.self, from: data)
        XCTAssertEqual(decoded, original, "TriggerMode should round-trip through Codable")
    }

    // MARK: - SupportedLanguage Tests

    func testSupportedLanguageHasEnglish() {
        XCTAssertTrue(
            SupportedLanguage.allCases.contains(.english),
            "Should include English"
        )
    }

    func testSupportedLanguageDisplayNames() {
        for language in SupportedLanguage.allCases {
            XCTAssertFalse(
                language.displayName.isEmpty,
                "\(language.rawValue) should have a display name"
            )
        }
    }

    func testSupportedLanguageRawValuesAreISO() {
        // All language raw values should be short ISO-like codes
        for language in SupportedLanguage.allCases {
            XCTAssertTrue(
                language.rawValue.count <= 5,
                "\(language.rawValue) should be a short language code"
            )
        }
    }

    // MARK: - Helpers

    /// Replicates the canProceedToNext() logic from OnboardingView
    /// so we can test it without instantiating SwiftUI views.
    private func onboardingCanProceed(
        step: Int,
        micGranted: Bool,
        accessibilityGranted: Bool,
        hotkeySet: Bool
    ) -> Bool {
        switch step {
        case 1: return micGranted
        case 2: return accessibilityGranted
        case 3: return hotkeySet
        default: return true
        }
    }
}

#endif
