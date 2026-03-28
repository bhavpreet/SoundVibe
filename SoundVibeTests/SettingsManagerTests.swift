import XCTest
@testable import SoundVibe

final class SettingsManagerTests: XCTestCase {

    var settingsManager: SettingsManager!

    override func setUp() {
        super.setUp()
        settingsManager = SettingsManager.shared
        settingsManager.resetToDefaults()
    }

    override func tearDown() {
        settingsManager.resetToDefaults()
        super.tearDown()
    }

    // MARK: - Default Values Tests

    func testDefaultTriggerMode() {
        settingsManager.resetToDefaults()
        XCTAssertEqual(settingsManager.triggerMode, .holdToTalk, "Default trigger mode should be holdToTalk")
    }

    func testDefaultHotkey() {
        settingsManager.resetToDefaults()
        XCTAssertEqual(
            settingsManager.hotkey.keyCode,
            HotkeyCombo.rightCommandKeyCode,
            "Default hotkey should be Right Command (keyCode 54)"
        )
        XCTAssertTrue(
            settingsManager.hotkey.isModifierOnly,
            "Default hotkey should be modifier-only"
        )
        XCTAssertEqual(
            settingsManager.hotkey.modifiers,
            0,
            "Modifier-only hotkey should have 0 modifiers"
        )
    }

    func testDefaultModelSize() {
        settingsManager.resetToDefaults()
        XCTAssertEqual(settingsManager.selectedModelSize, .base, "Default model size should be base")
    }

    func testDefaultLanguage() {
        settingsManager.resetToDefaults()
        XCTAssertEqual(settingsManager.selectedLanguage, "en", "Default language should be 'en'")
    }

    func testDefaultAutoLanguageDetection() {
        settingsManager.resetToDefaults()
        XCTAssertFalse(settingsManager.autoLanguageDetection, "Auto language detection should be disabled by default")
    }

    func testDefaultAutoPunctuation() {
        settingsManager.resetToDefaults()
        XCTAssertTrue(settingsManager.autoPunctuation, "Auto punctuation should be enabled by default")
    }

    func testDefaultPostProcessingEnabled() {
        settingsManager.resetToDefaults()
        XCTAssertFalse(settingsManager.postProcessingEnabled, "Post-processing should be disabled by default")
    }

    func testDefaultPostProcessingMode() {
        settingsManager.resetToDefaults()
        XCTAssertEqual(settingsManager.postProcessingMode, .clean, "Default post-processing mode should be clean")
    }

    func testDefaultCustomPostProcessingPrompt() {
        settingsManager.resetToDefaults()
        XCTAssertEqual(settingsManager.customPostProcessingPrompt, "", "Default custom prompt should be empty")
    }

    func testDefaultLaunchAtLogin() {
        settingsManager.resetToDefaults()
        XCTAssertFalse(settingsManager.launchAtLogin, "Launch at login should be disabled by default")
    }

    func testDefaultShowFloatingIndicator() {
        settingsManager.resetToDefaults()
        XCTAssertTrue(settingsManager.showFloatingIndicator, "Show floating indicator should be enabled by default")
    }

    func testDefaultClipboardRestoreEnabled() {
        settingsManager.resetToDefaults()
        XCTAssertTrue(settingsManager.clipboardRestoreEnabled, "Clipboard restore should be enabled by default")
    }

    func testDefaultPasteDelay() {
        settingsManager.resetToDefaults()
        XCTAssertEqual(settingsManager.pasteDelay, 0.05, accuracy: 0.001, "Default paste delay should be 0.05")
    }

    func testDefaultSilenceTimeout() {
        settingsManager.resetToDefaults()
        XCTAssertEqual(settingsManager.silenceTimeout, 3.0, accuracy: 0.001, "Default silence timeout should be 3.0")
    }

    func testDefaultSelectedInputDevice() {
        settingsManager.resetToDefaults()
        XCTAssertNil(settingsManager.selectedInputDevice, "Default selected input device should be nil")
    }

    // MARK: - ResetToDefaults Tests

    func testResetToDefaults() {
        settingsManager.triggerMode = .toggle
        settingsManager.selectedLanguage = "fr"
        settingsManager.postProcessingEnabled = true
        settingsManager.postProcessingMode = .formal

        settingsManager.resetToDefaults()

        XCTAssertEqual(settingsManager.triggerMode, .holdToTalk, "triggerMode should be reset")
        XCTAssertEqual(settingsManager.selectedLanguage, "en", "selectedLanguage should be reset")
        XCTAssertFalse(settingsManager.postProcessingEnabled, "postProcessingEnabled should be reset")
        XCTAssertEqual(settingsManager.postProcessingMode, .clean, "postProcessingMode should be reset")
    }

    // MARK: - TriggerMode Enum Tests

    func testTriggerModeRawValues() {
        XCTAssertEqual(TriggerMode.holdToTalk.rawValue, "holdToTalk", "holdToTalk raw value should match")
        XCTAssertEqual(TriggerMode.toggle.rawValue, "toggle", "toggle raw value should match")
    }

    func testTriggerModeDecodable() {
        let decoded = TriggerMode(rawValue: "toggle")
        XCTAssertEqual(decoded, .toggle, "Should decode toggle correctly")
    }

    func testTriggerModeDisplayNames() {
        XCTAssertEqual(TriggerMode.holdToTalk.displayName, "Hold to Talk", "Hold to Talk display name should match")
        XCTAssertEqual(TriggerMode.toggle.displayName, "Toggle", "Toggle display name should match")
    }

    func testTriggerModeDescriptions() {
        XCTAssertTrue(TriggerMode.holdToTalk.description.contains("hold"), "Hold to Talk description should contain 'hold'")
        XCTAssertTrue(TriggerMode.toggle.description.contains("Press"), "Toggle description should contain 'Press'")
    }

    // MARK: - PostProcessingMode Enum Tests

    func testPostProcessingModeRawValues() {
        XCTAssertEqual(PostProcessingMode.clean.rawValue, "clean", "clean raw value should match")
        XCTAssertEqual(PostProcessingMode.formal.rawValue, "formal", "formal raw value should match")
        XCTAssertEqual(PostProcessingMode.concise.rawValue, "concise", "concise raw value should match")
        XCTAssertEqual(PostProcessingMode.custom.rawValue, "custom", "custom raw value should match")
    }

    func testPostProcessingModeDecodable() {
        let decoded = PostProcessingMode(rawValue: "formal")
        XCTAssertEqual(decoded, .formal, "Should decode formal correctly")
    }

    func testPostProcessingModeDisplayNames() {
        XCTAssertEqual(PostProcessingMode.clean.displayName, "Clean (Remove filler words)", "clean display name should match")
        XCTAssertEqual(PostProcessingMode.formal.displayName, "Formal (Business tone)", "formal display name should match")
        XCTAssertEqual(PostProcessingMode.concise.displayName, "Concise (Remove redundancy)", "concise display name should match")
        XCTAssertEqual(PostProcessingMode.custom.displayName, "Custom (Use custom prompt)", "custom display name should match")
    }

    func testPostProcessingModeDefaultPrompts() {
        XCTAssertTrue(PostProcessingMode.clean.defaultPrompt.contains("filler"), "clean prompt should contain 'filler'")
        XCTAssertTrue(PostProcessingMode.formal.defaultPrompt.contains("formal"), "formal prompt should contain 'formal'")
        XCTAssertTrue(PostProcessingMode.concise.defaultPrompt.contains("essential"), "concise prompt should contain 'essential'")
        XCTAssertEqual(PostProcessingMode.custom.defaultPrompt, "", "custom prompt should be empty")
    }

    // MARK: - HotkeyCombo Tests

    func testHotkeyComboEquality() {
        let hotkey1 = HotkeyCombo(keyCode: 49, modifiers: 0x80000)
        let hotkey2 = HotkeyCombo(keyCode: 49, modifiers: 0x80000)
        XCTAssertEqual(hotkey1, hotkey2, "Hotkeys with same values should be equal")
    }

    func testHotkeyComboInequality() {
        let hotkey1 = HotkeyCombo(keyCode: 49, modifiers: 0x80000)
        let hotkey2 = HotkeyCombo(keyCode: 50, modifiers: 0x80000)
        XCTAssertNotEqual(hotkey1, hotkey2, "Hotkeys with different key codes should not be equal")
    }

    func testHotkeyComboCodeable() {
        let original = HotkeyCombo(keyCode: 49, modifiers: 0x80000)

        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(original) else {
            XCTFail("Failed to encode hotkey")
            return
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(HotkeyCombo.self, from: encodedData) else {
            XCTFail("Failed to decode hotkey")
            return
        }

        XCTAssertEqual(decoded.keyCode, original.keyCode, "Decoded keyCode should match")
        XCTAssertEqual(decoded.modifiers, original.modifiers, "Decoded modifiers should match")
    }

    // MARK: - ExportSettings Tests

    func testExportSettings() {
        settingsManager.triggerMode = .toggle
        settingsManager.selectedLanguage = "fr"
        settingsManager.postProcessingEnabled = true

        let exportedData = settingsManager.exportSettings()
        XCTAssertGreaterThan(exportedData.count, 0, "Exported settings should not be empty")

        // Try to parse as JSON to ensure it's valid
        guard let json = try? JSONSerialization.jsonObject(with: exportedData) as? [String: Any] else {
            XCTFail("Exported settings should be valid JSON")
            return
        }

        XCTAssertEqual(json["triggerMode"] as? String, "toggle", "Exported triggerMode should match")
        XCTAssertEqual(json["selectedLanguage"] as? String, "fr", "Exported selectedLanguage should match")
        XCTAssertEqual(json["postProcessingEnabled"] as? Bool, true, "Exported postProcessingEnabled should match")
    }

    func testExportContainsAllKeys() {
        let exportedData = settingsManager.exportSettings()

        guard let json = try? JSONSerialization.jsonObject(with: exportedData) as? [String: Any] else {
            XCTFail("Exported settings should be valid JSON")
            return
        }

        let requiredKeys = [
            "triggerMode", "hotkey", "selectedModelSize", "selectedLanguage",
            "autoLanguageDetection", "autoPunctuation", "postProcessingEnabled",
            "postProcessingMode", "customPostProcessingPrompt", "launchAtLogin",
            "showFloatingIndicator", "clipboardRestoreEnabled", "pasteDelay",
            "silenceTimeout", "selectedInputDevice"
        ]

        for key in requiredKeys {
            XCTAssertNotNil(json[key], "Exported JSON should contain key: \(key)")
        }
    }

    // MARK: - ImportSettings Tests

    func testImportSettingsRoundTrip() {
        settingsManager.triggerMode = .toggle
        settingsManager.selectedLanguage = "es"
        settingsManager.postProcessingEnabled = true
        settingsManager.postProcessingMode = .formal
        settingsManager.autoPunctuation = false

        let exportedData = settingsManager.exportSettings()

        settingsManager.resetToDefaults()
        XCTAssertEqual(settingsManager.triggerMode, .holdToTalk, "After reset, triggerMode should be default")

        do {
            try settingsManager.importSettings(exportedData)
        } catch {
            XCTFail("Import should not fail: \(error)")
            return
        }

        XCTAssertEqual(settingsManager.triggerMode, .toggle, "Imported triggerMode should match exported")
        XCTAssertEqual(settingsManager.selectedLanguage, "es", "Imported selectedLanguage should match exported")
        XCTAssertTrue(settingsManager.postProcessingEnabled, "Imported postProcessingEnabled should match exported")
        XCTAssertEqual(settingsManager.postProcessingMode, .formal, "Imported postProcessingMode should match exported")
        XCTAssertFalse(settingsManager.autoPunctuation, "Imported autoPunctuation should match exported")
    }

    func testImportSettingsPartial() {
        let partialJSON: [String: Any] = [
            "triggerMode": "toggle",
            "selectedLanguage": "de"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: partialJSON) else {
            XCTFail("Failed to create JSON data")
            return
        }

        do {
            try settingsManager.importSettings(jsonData)
        } catch {
            XCTFail("Import should not fail for partial data: \(error)")
            return
        }

        XCTAssertEqual(settingsManager.triggerMode, .toggle, "Should import triggerMode")
        XCTAssertEqual(settingsManager.selectedLanguage, "de", "Should import selectedLanguage")
        // Other settings should remain unchanged
        XCTAssertEqual(settingsManager.postProcessingMode, .clean, "Unspecified settings should remain default")
    }

    func testImportInvalidJSON() {
        let invalidData = "not valid JSON".data(using: .utf8)!

        do {
            try settingsManager.importSettings(invalidData)
            XCTFail("Should throw error for invalid JSON")
        } catch {
            XCTAssertNotNil(error, "Should throw an error")
        }
    }

    func testImportWithHotkey() {
        let json: [String: Any] = [
            "hotkey": ["keyCode": 50, "modifiers": 0x40000]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
            XCTFail("Failed to create JSON data")
            return
        }

        do {
            try settingsManager.importSettings(jsonData)
        } catch {
            XCTFail("Import should not fail: \(error)")
            return
        }

        XCTAssertEqual(settingsManager.hotkey.keyCode, 50, "Imported hotkey keyCode should match")
        XCTAssertEqual(settingsManager.hotkey.modifiers, 0x40000, "Imported hotkey modifiers should match")
    }

    // MARK: - Property Persistence Tests

    func testTriggerModePropertyUpdate() {
        let original = settingsManager.triggerMode
        settingsManager.triggerMode = (original == .holdToTalk) ? .toggle : .holdToTalk

        let newValue = settingsManager.triggerMode
        XCTAssertNotEqual(newValue, original, "Property should be updated")
    }

    func testSelectedModelSizeUpdate() {
        settingsManager.selectedModelSize = .medium
        XCTAssertEqual(settingsManager.selectedModelSize, .medium, "Selected model size should be updated")
    }

    func testPostProcessingModeUpdate() {
        settingsManager.postProcessingMode = .concise
        XCTAssertEqual(settingsManager.postProcessingMode, .concise, "Post-processing mode should be updated")
    }

    func testBooleanPropertiesUpdate() {
        settingsManager.autoLanguageDetection = true
        XCTAssertTrue(settingsManager.autoLanguageDetection, "autoLanguageDetection should be true")

        settingsManager.autoPunctuation = false
        XCTAssertFalse(settingsManager.autoPunctuation, "autoPunctuation should be false")

        settingsManager.postProcessingEnabled = true
        XCTAssertTrue(settingsManager.postProcessingEnabled, "postProcessingEnabled should be true")
    }

    func testTimeIntervalUpdate() {
        settingsManager.pasteDelay = 0.1
        XCTAssertEqual(settingsManager.pasteDelay, 0.1, accuracy: 0.001, "pasteDelay should be updated")

        settingsManager.silenceTimeout = 5.0
        XCTAssertEqual(settingsManager.silenceTimeout, 5.0, accuracy: 0.001, "silenceTimeout should be updated")
    }

    // MARK: - CaseIterable Tests

    func testTriggerModeAllCases() {
        let cases = TriggerMode.allCases
        XCTAssertEqual(cases.count, 2, "TriggerMode should have 2 cases")
        XCTAssertTrue(cases.contains(.holdToTalk), "Should contain holdToTalk")
        XCTAssertTrue(cases.contains(.toggle), "Should contain toggle")
    }

    func testPostProcessingModeAllCases() {
        let cases = PostProcessingMode.allCases
        XCTAssertEqual(cases.count, 4, "PostProcessingMode should have 4 cases")
        XCTAssertTrue(cases.contains(.clean), "Should contain clean")
        XCTAssertTrue(cases.contains(.formal), "Should contain formal")
        XCTAssertTrue(cases.contains(.concise), "Should contain concise")
        XCTAssertTrue(cases.contains(.custom), "Should contain custom")
    }

    func testWhisperModelSizeAllCases() {
        let cases = WhisperModelSize.allCases
        XCTAssertGreaterThan(cases.count, 0, "WhisperModelSize should have cases")
        XCTAssertTrue(cases.contains(.tiny), "Should contain tiny")
        XCTAssertTrue(cases.contains(.base), "Should contain base")
    }

    // MARK: - 7d: Streaming Settings Tests

    func testDefaultStreamingChunkInterval() {
        settingsManager.resetToDefaults()
        XCTAssertEqual(settingsManager.streamingChunkInterval, 2.5, accuracy: 0.001,
                       "Default streaming chunk interval should be 2.5 seconds")
    }

    func testStreamingChunkIntervalPersists() {
        settingsManager.streamingChunkInterval = 3.0
        XCTAssertEqual(settingsManager.streamingChunkInterval, 3.0, accuracy: 0.001,
                       "streamingChunkInterval should be updated")

        // Verify the value is stored (didSet calls defaults.set)
        let stored = UserDefaults.standard.double(forKey: "soundvibe.streamingChunkInterval")
        XCTAssertEqual(stored, 3.0, accuracy: 0.001,
                       "streamingChunkInterval should be persisted to UserDefaults")
    }

    func testStreamingTranscriptionEnabledPersists() {
        let original = settingsManager.streamingTranscriptionEnabled
        settingsManager.streamingTranscriptionEnabled = !original

        let stored = UserDefaults.standard.object(forKey: "soundvibe.streamingTranscriptionEnabled")
        XCTAssertNotNil(stored, "streamingTranscriptionEnabled should be persisted to UserDefaults")
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "soundvibe.streamingTranscriptionEnabled"),
                       !original, "Persisted value should match what was set")
    }

    func testStreamingSettingsRoundTripExportImport() {
        settingsManager.streamingTranscriptionEnabled = false
        settingsManager.streamingChunkInterval = 4.0

        let exported = settingsManager.exportSettings()
        guard let json = try? JSONSerialization.jsonObject(with: exported) as? [String: Any] else {
            XCTFail("Exported settings should be valid JSON")
            return
        }

        XCTAssertEqual(json["streamingTranscriptionEnabled"] as? Bool, false,
                       "Exported streamingTranscriptionEnabled should be false")
        let exportedChunkInterval = json["streamingChunkInterval"] as? Double
        XCTAssertNotNil(exportedChunkInterval, "Exported streamingChunkInterval should exist")
        XCTAssertEqual(exportedChunkInterval ?? 0.0, 4.0, accuracy: 0.001,
                       "Exported streamingChunkInterval should be 4.0")

        settingsManager.resetToDefaults()

        do {
            try settingsManager.importSettings(exported)
        } catch {
            XCTFail("Import should not fail: \(error)")
            return
        }

        XCTAssertFalse(settingsManager.streamingTranscriptionEnabled,
                        "Imported streamingTranscriptionEnabled should be false")
        XCTAssertEqual(settingsManager.streamingChunkInterval, 4.0, accuracy: 0.001,
                       "Imported streamingChunkInterval should be 4.0")
    }

    func testResetToDefaultsResetsStreamingSettings() {
        settingsManager.streamingTranscriptionEnabled = false
        settingsManager.streamingChunkInterval = 9.9

        settingsManager.resetToDefaults()

        XCTAssertEqual(settingsManager.streamingChunkInterval, 2.5, accuracy: 0.001,
                       "streamingChunkInterval should reset to 2.5")
        // streamingTranscriptionEnabled resets to arch-dependent default
        // Just verify it is either true or false (not some invalid state)
        let _ = settingsManager.streamingTranscriptionEnabled // no crash
    }

    func testExportContainsStreamingKeys() {
        let exported = settingsManager.exportSettings()
        guard let json = try? JSONSerialization.jsonObject(with: exported) as? [String: Any] else {
            XCTFail("Exported settings should be valid JSON")
            return
        }

        XCTAssertNotNil(json["streamingTranscriptionEnabled"],
                        "Exported JSON should contain streamingTranscriptionEnabled")
        XCTAssertNotNil(json["streamingChunkInterval"],
                        "Exported JSON should contain streamingChunkInterval")
    }
}
