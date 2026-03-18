import XCTest
@testable import SoundVibe

final class PostProcessingPipelineTests: XCTestCase {

    var pipeline: PostProcessingPipeline!
    var mockProcessor: MockPostProcessor!
    var defaultSettings: DefaultSettingsManager!

    override func setUp() {
        super.setUp()
        mockProcessor = MockPostProcessor()
        pipeline = PostProcessingPipeline(postProcessor: mockProcessor)
        defaultSettings = DefaultSettingsManager()
    }

    override func tearDown() {
        pipeline = nil
        mockProcessor = nil
        defaultSettings = nil
        super.tearDown()
    }

    // MARK: - Voice Command Parsing Tests

    func testVoiceCommandsParsedBeforeLLM() async {
        let input = "hello period world"
        let settings = DefaultSettingsManager(postProcessingEnabled: false)

        do {
            let result = try await pipeline.process(input, settings: settings)
            XCTAssertEqual(result, "hello. world", "Voice commands should be parsed even without LLM processing")
        } catch {
            XCTFail("Processing should not fail: \(error)")
        }
    }

    func testNewLineCommandInPipeline() async {
        let input = "first new line second"
        let settings = DefaultSettingsManager(postProcessingEnabled: false)

        do {
            let result = try await pipeline.process(input, settings: settings)
            XCTAssertTrue(result.contains("\n"), "Pipeline should parse new line command")
        } catch {
            XCTFail("Processing should not fail: \(error)")
        }
    }

    func testCommaCommandInPipeline() async {
        let input = "hello comma world"
        let settings = DefaultSettingsManager(postProcessingEnabled: false)

        do {
            let result = try await pipeline.process(input, settings: settings)
            XCTAssertEqual(result, "hello, world", "Pipeline should parse comma command")
        } catch {
            XCTFail("Processing should not fail: \(error)")
        }
    }

    // MARK: - Post-Processing Disabled Tests

    func testPostProcessingDisabledReturnsCommandParsedText() async {
        let input = "hello period test comma here"
        let settings = DefaultSettingsManager(postProcessingEnabled: false)

        do {
            let result = try await pipeline.process(input, settings: settings)
            XCTAssertEqual(result, "hello. test, here", "Should return voice-command-parsed text when post-processing is disabled")
        } catch {
            XCTFail("Processing should not fail: \(error)")
        }
    }

    func testDisabledPostProcessingNoLLMCall() async {
        let input = "hello world"
        let settings = DefaultSettingsManager(postProcessingEnabled: false)

        do {
            let result = try await pipeline.process(input, settings: settings)
            XCTAssertEqual(result, input, "Should not call LLM when post-processing is disabled")
        } catch {
            XCTFail("Processing should not fail: \(error)")
        }
    }

    // MARK: - Post-Processing Enabled Tests

    func testPostProcessingEnabledCallsProcessor() async throws {
        try await mockProcessor.loadModel(named: "test-model")

        let input = "hello world"
        let settings = DefaultSettingsManager(
            postProcessingEnabled: true,
            postProcessingMode: .clean
        )

        do {
            let result = try await pipeline.process(input, settings: settings)
            // MockProcessor returns "[mode] text"
            XCTAssertTrue(result.contains("[clean]"), "Pipeline should call processor with correct mode")
        } catch {
            XCTFail("Processing should not fail: \(error)")
        }
    }

    func testPostProcessingWithDifferentModes() async throws {
        try await mockProcessor.loadModel(named: "test-model")

        let input = "test text"
        let modes: [PostProcessingMode] = [.clean, .formal, .concise, .custom]

        for mode in modes {
            let settings = DefaultSettingsManager(
                postProcessingEnabled: true,
                postProcessingMode: mode
            )

            do {
                let result = try await pipeline.process(input, settings: settings)
                XCTAssertTrue(
                    result.contains("[\(mode.rawValue)]"),
                    "Pipeline should apply \(mode.rawValue) mode"
                )
            } catch {
                XCTFail("Processing should not fail for mode \(mode.rawValue): \(error)")
            }
        }
    }

    // MARK: - Error Handling Tests

    func testGracefulDegradationWhenProcessorFails() async {
        let input = "hello period world"
        // Processor not loaded, should fail
        let settings = DefaultSettingsManager(postProcessingEnabled: true)

        do {
            let result = try await pipeline.process(input, settings: settings)
            // Should return voice-command-parsed text on failure
            XCTAssertEqual(result, "hello. world", "Should return command-parsed text when processor fails")
        } catch {
            XCTFail("Pipeline should handle processor failure gracefully: \(error)")
        }
    }

    func testErrorReturnsCommandParsedText() async {
        let input = "test comma here period"
        let settings = DefaultSettingsManager(postProcessingEnabled: true)

        do {
            let result = try await pipeline.process(input, settings: settings)
            // Even if processor fails, command parsing should succeed
            XCTAssertTrue(result.contains(","), "Command parsing should be applied")
            XCTAssertTrue(result.contains("."), "Command parsing should be applied")
        } catch {
            XCTFail("Pipeline should not throw error: \(error)")
        }
    }

    // MARK: - Pipeline Without Processor Tests

    func testPipelineWithoutProcessorWorks() async {
        let pipelineNoProcessor = PostProcessingPipeline(postProcessor: nil)
        let input = "hello period"
        let settings = DefaultSettingsManager(postProcessingEnabled: false)

        do {
            let result = try await pipelineNoProcessor.process(input, settings: settings)
            XCTAssertEqual(result, "hello.", "Pipeline without processor should still parse commands")
        } catch {
            XCTFail("Pipeline without processor should work: \(error)")
        }
    }

    func testPipelineWithoutProcessorIgnoresPostProcessing() async {
        let pipelineNoProcessor = PostProcessingPipeline(postProcessor: nil)
        let input = "hello world"
        let settings = DefaultSettingsManager(postProcessingEnabled: true)

        do {
            let result = try await pipelineNoProcessor.process(input, settings: settings)
            XCTAssertEqual(result, input, "Pipeline should return command-parsed text when no processor available")
        } catch {
            XCTFail("Pipeline should handle missing processor: \(error)")
        }
    }

    // MARK: - Mock Processor Tests

    func testMockProcessorInitialization() {
        let mock = MockPostProcessor()
        XCTAssertTrue(mock.isAvailable, "Mock processor should be available")
        XCTAssertFalse(mock.isProcessing, "Mock processor should not be processing initially")
    }

    func testMockProcessorLoadModel() async {
        let mock = MockPostProcessor()

        do {
            try await mock.loadModel(named: "test-model")
            // No assertion needed, just verify no error
        } catch {
            XCTFail("Mock processor should load model without error: \(error)")
        }
    }

    func testMockProcessorWithoutLoadingFails() async {
        let mock = MockPostProcessor(modelLoaded: false)

        do {
            let result = try await mock.process("test", mode: .clean)
            XCTFail("Mock processor should fail when model not loaded, but got: \(result)")
        } catch is PostProcessingError {
            // Expected
        } catch {
            XCTFail("Should throw PostProcessingError: \(error)")
        }
    }

    func testMockProcessorReturnsMarkedText() async {
        let mock = MockPostProcessor(modelLoaded: true)

        do {
            let result = try await mock.process("test input", mode: .formal)
            XCTAssertTrue(result.contains("[formal]"), "Mock should mark processed text with mode")
            XCTAssertTrue(result.contains("test input"), "Mock should preserve original text")
        } catch {
            XCTFail("Mock processor should not fail: \(error)")
        }
    }

    // MARK: - Complex Scenarios Tests

    func testVoiceCommandsThenLLMProcessing() async throws {
        try await mockProcessor.loadModel(named: "test-model")

        let input = "hello period how are you question mark"
        let settings = DefaultSettingsManager(
            postProcessingEnabled: true,
            postProcessingMode: .clean
        )

        do {
            let result = try await pipeline.process(input, settings: settings)
            // Commands should be parsed first: "hello. how are you?"
            // Then wrapped by mock: "[clean] hello. how are you?"
            XCTAssertTrue(result.contains("."), "Period should be parsed")
            XCTAssertTrue(result.contains("?"), "Question mark should be parsed")
            XCTAssertTrue(result.contains("[clean]"), "LLM processing should be applied")
        } catch {
            XCTFail("Complex scenario should work: \(error)")
        }
    }

    func testEmptyTextProcessing() async {
        let input = ""
        let settings = DefaultSettingsManager(postProcessingEnabled: false)

        do {
            let result = try await pipeline.process(input, settings: settings)
            XCTAssertEqual(result, "", "Empty text should remain empty")
        } catch {
            XCTFail("Processing empty text should not fail: \(error)")
        }
    }

    func testWhitespaceOnlyTextProcessing() async {
        let input = "   \n  \t  "
        let settings = DefaultSettingsManager(postProcessingEnabled: false)

        do {
            let result = try await pipeline.process(input, settings: settings)
            XCTAssertEqual(result, input, "Whitespace-only text should be preserved")
        } catch {
            XCTFail("Processing whitespace text should not fail: \(error)")
        }
    }

    func testMultipleCommandsProcessing() async {
        let input = "first comma second period third new line fourth"
        let settings = DefaultSettingsManager(postProcessingEnabled: false)

        do {
            let result = try await pipeline.process(input, settings: settings)
            XCTAssertTrue(result.contains(","), "Comma should be parsed")
            XCTAssertTrue(result.contains("."), "Period should be parsed")
            XCTAssertTrue(result.contains("\n"), "Newline should be parsed")
        } catch {
            XCTFail("Multiple commands should be processed: \(error)")
        }
    }

    // MARK: - DefaultSettingsManager Tests

    func testDefaultSettingsManagerDefaults() {
        let settings = DefaultSettingsManager()
        XCTAssertFalse(settings.postProcessingEnabled, "Default should have post-processing disabled")
        XCTAssertEqual(settings.postProcessingMode, .clean, "Default mode should be clean")
        XCTAssertEqual(settings.customPostProcessingPrompt, "", "Default custom prompt should be empty")
    }

    func testDefaultSettingsManagerWithCustomValues() {
        let settings = DefaultSettingsManager(
            postProcessingEnabled: true,
            postProcessingMode: .formal,
            customPostProcessingPrompt: "Be professional"
        )

        XCTAssertTrue(settings.postProcessingEnabled, "Should be enabled")
        XCTAssertEqual(settings.postProcessingMode, .formal, "Mode should be formal")
        XCTAssertEqual(settings.customPostProcessingPrompt, "Be professional", "Custom prompt should be set")
    }

    // MARK: - Sendable Protocol Tests

    func testPipelineIsSendable() async {
        let pipelineTest = PostProcessingPipeline()
        let input = "test period"
        let settings = DefaultSettingsManager(postProcessingEnabled: false)

        // Test that pipeline can be used across isolation boundaries
        let result = try? await pipelineTest.process(input, settings: settings)
        XCTAssertEqual(result, "test.", "Pipeline should work across async boundaries")
    }

    func testMockProcessorIsSendable() async {
        let mock = MockPostProcessor()
        try? await mock.loadModel(named: "test")

        // Mock should work across isolation boundaries
        let result = try? await mock.process("test", mode: .clean)
        XCTAssertNotNil(result, "Mock processor should work across async boundaries")
    }
}
