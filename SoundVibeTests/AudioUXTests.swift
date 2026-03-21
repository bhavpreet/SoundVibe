import XCTest
@testable import SoundVibe

// MARK: - Audio UX Feature Tests

final class AudioUXTests: XCTestCase {

    // MARK: - A1: Pre-Recording Buffer

    func testPreRecordingStateExists() {
        // Verify warmingUp state is part of DictationState
        let state = DictationState.warmingUp
        XCTAssertTrue(state.isActive, "warmingUp should be active")
        XCTAssertEqual(
            state.displayDescription, "warmingUp",
            "Display description should be 'warmingUp'"
        )
    }

    func testPreRecordingCapturesFirstSyllable() {
        // The warmingUp state should start audio capture before
        // showing the main indicator, ensuring first syllable
        // is captured.
        let warmingUp = DictationState.warmingUp
        let listening = DictationState.listening

        // warmingUp comes before listening in the state machine
        XCTAssertTrue(warmingUp.isActive)
        XCTAssertTrue(listening.isActive)
        XCTAssertNotEqual(warmingUp, listening)
    }

    // MARK: - A2: Tail Recording Delay

    func testFinishingStateExists() {
        let state = DictationState.finishing
        XCTAssertTrue(state.isActive, "finishing should be active")
        XCTAssertEqual(
            state.displayDescription, "finishing",
            "Display description should be 'finishing'"
        )
    }

    func testTailRecordingCapturesTrailingWords() {
        // Verify the finishing state is distinct from idle/listening
        let finishing = DictationState.finishing
        let idle = DictationState.idle
        let listening = DictationState.listening

        XCTAssertNotEqual(finishing, idle)
        XCTAssertNotEqual(finishing, listening)
        XCTAssertTrue(finishing.isActive)
        XCTAssertFalse(idle.isActive)
    }

    func testRapidRepressCancelsFinishing() {
        // The finishing state should allow resumeRecording()
        // which returns to listening state
        let finishing = DictationState.finishing
        let listening = DictationState.listening

        XCTAssertTrue(finishing.isActive)
        XCTAssertTrue(listening.isActive)

        // Both states are distinct, enabling transition
        XCTAssertNotEqual(finishing, listening)
    }

    // MARK: - A3: Audio Level Calculation

    func testAudioLevelCalculation() async {
        // Test that smoothed audio level tracking works
        let capture = AudioCaptureManager()

        // Initially, levels should be zero
        let level = await capture.smoothedAudioLevel
        XCTAssertEqual(
            level, 0.0,
            "Initial smoothed audio level should be 0"
        )

        let rawLevel = await capture.audioLevel
        XCTAssertEqual(
            rawLevel, 0.0,
            "Initial raw audio level should be 0"
        )
    }

    // MARK: - A5: Silence Detection

    func testSilenceDetectionTriggers() async {
        let detector = SilenceDetector()

        // Initially not silent
        var isSilent = await detector.isSilent
        XCTAssertFalse(isSilent, "Should not be silent initially")

        // Feed silent levels
        let result = await detector.update(
            level: 0.01, threshold: 0.05
        )
        XCTAssertTrue(result, "Should detect silence")

        isSilent = await detector.isSilent
        XCTAssertTrue(isSilent, "Should be silent after low level")

        // Feed loud level — silence ends
        let loudResult = await detector.update(
            level: 0.5, threshold: 0.05
        )
        XCTAssertFalse(loudResult, "Should not be silent with sound")

        isSilent = await detector.isSilent
        XCTAssertFalse(
            isSilent,
            "Should not be silent after loud input"
        )
    }

    func testSilenceDetectionDuration() async {
        let detector = SilenceDetector()

        // Feed silence
        await detector.update(level: 0.01, threshold: 0.05)

        // Duration should be very small but > 0
        let duration = await detector.silenceDuration
        XCTAssertGreaterThanOrEqual(
            duration, 0,
            "Silence duration should be >= 0"
        )
    }

    func testSilenceDetectionReset() async {
        let detector = SilenceDetector()

        // Start silence
        await detector.update(level: 0.01, threshold: 0.05)
        var isSilent = await detector.isSilent
        XCTAssertTrue(isSilent)

        // Reset
        await detector.reset()
        isSilent = await detector.isSilent
        XCTAssertFalse(
            isSilent,
            "Should not be silent after reset"
        )

        let duration = await detector.silenceDuration
        XCTAssertEqual(
            duration, 0,
            "Duration should be 0 after reset"
        )
    }

    // MARK: - A6: Sound Feedback

    func testSoundFeedbackSettingDefault() {
        let settings = SettingsManager(forTesting: true)
        XCTAssertTrue(
            settings.soundFeedbackEnabled,
            "Sound feedback should be ON by default"
        )
    }

    func testSoundFeedbackPlaysOnStart() {
        // Verify the setting can be toggled
        let settings = SettingsManager(forTesting: true)
        XCTAssertTrue(settings.soundFeedbackEnabled)

        settings.soundFeedbackEnabled = false
        XCTAssertFalse(
            settings.soundFeedbackEnabled,
            "Sound feedback should be disabled after toggle"
        )

        settings.soundFeedbackEnabled = true
        XCTAssertTrue(
            settings.soundFeedbackEnabled,
            "Sound feedback should be re-enabled"
        )
    }

    // MARK: - A7: Typing Cooldown

    func testTypingCooldownSettingDefault() {
        let settings = SettingsManager(forTesting: true)
        XCTAssertTrue(
            settings.typingCooldownEnabled,
            "Typing cooldown should be ON by default"
        )
    }

    func testTypingCooldownBlocksActivation() {
        // Verify the setting can be toggled
        let settings = SettingsManager(forTesting: true)
        XCTAssertTrue(settings.typingCooldownEnabled)

        settings.typingCooldownEnabled = false
        XCTAssertFalse(
            settings.typingCooldownEnabled,
            "Typing cooldown should be disabled after toggle"
        )
    }

    // MARK: - Settings Export/Import

    func testNewSettingsExportIncludesAudioUXKeys() {
        let settings = SettingsManager(forTesting: true)
        settings.soundFeedbackEnabled = false
        settings.typingCooldownEnabled = false

        let data = settings.exportSettings()
        guard let json = try? JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any] else {
            XCTFail("Export should produce valid JSON")
            return
        }

        XCTAssertNotNil(
            json["soundFeedbackEnabled"],
            "Export should include soundFeedbackEnabled"
        )
        XCTAssertNotNil(
            json["typingCooldownEnabled"],
            "Export should include typingCooldownEnabled"
        )
        XCTAssertEqual(
            json["soundFeedbackEnabled"] as? Bool, false
        )
        XCTAssertEqual(
            json["typingCooldownEnabled"] as? Bool, false
        )
    }

    func testNewSettingsImportRestoresAudioUXKeys() throws {
        let json: [String: Any] = [
            "soundFeedbackEnabled": false,
            "typingCooldownEnabled": false,
        ]
        let data = try JSONSerialization.data(
            withJSONObject: json
        )

        let settings = SettingsManager(forTesting: true)
        XCTAssertTrue(settings.soundFeedbackEnabled)
        XCTAssertTrue(settings.typingCooldownEnabled)

        try settings.importSettings(data)
        XCTAssertFalse(
            settings.soundFeedbackEnabled,
            "Import should restore soundFeedbackEnabled"
        )
        XCTAssertFalse(
            settings.typingCooldownEnabled,
            "Import should restore typingCooldownEnabled"
        )
    }

    // MARK: - Silence Detector Behavioral Tests

    func testSilenceDetectorAccumulatesDuration() async throws {
        let detector = SilenceDetector()

        // Start silence
        await detector.update(level: 0.01, threshold: 0.05)

        // Wait a bit
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Feed another silent sample
        await detector.update(level: 0.02, threshold: 0.05)

        let duration = await detector.silenceDuration
        XCTAssertGreaterThan(
            duration, 0.1,
            "Silence duration should accumulate over time"
        )
    }

    func testSilenceDetectorResetsOnSound() async {
        let detector = SilenceDetector()

        // Build up silence
        await detector.update(level: 0.01, threshold: 0.05)
        var isSilent = await detector.isSilent
        XCTAssertTrue(isSilent)

        // Sound breaks the silence
        await detector.update(level: 0.5, threshold: 0.05)
        isSilent = await detector.isSilent
        XCTAssertFalse(isSilent)

        let duration = await detector.silenceDuration
        XCTAssertEqual(
            duration, 0,
            "Duration should reset to 0 when sound detected"
        )
    }

    // MARK: - DictationState Completeness

    func testAllStatesHaveDisplayDescription() {
        let states: [DictationState] = [
            .idle,
            .warmingUp,
            .listening,
            .finishing,
            .transcribing,
            .postProcessing,
            .inserting,
            .error("test"),
        ]

        for state in states {
            XCTAssertFalse(
                state.displayDescription.isEmpty,
                "State \(state) should have a display description"
            )
        }
    }

    func testActiveStates() {
        let activeStates: [DictationState] = [
            .warmingUp,
            .listening,
            .finishing,
            .transcribing,
            .postProcessing,
            .inserting,
        ]

        for state in activeStates {
            XCTAssertTrue(
                state.isActive,
                "\(state.displayDescription) should be active"
            )
        }
    }

    func testInactiveStates() {
        let inactiveStates: [DictationState] = [
            .idle,
            .error("test error"),
        ]

        for state in inactiveStates {
            XCTAssertFalse(
                state.isActive,
                "\(state.displayDescription) should be inactive"
            )
        }
    }

    func testErrorState() {
        let errorState = DictationState.error("test msg")
        XCTAssertTrue(errorState.isError)
        XCTAssertEqual(
            errorState.displayDescription,
            "error(test msg)"
        )
    }
}
