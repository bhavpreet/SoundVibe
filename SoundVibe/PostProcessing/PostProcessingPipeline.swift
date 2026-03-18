import Foundation

// MARK: - Voice Command Parser (Interface)

/// Parses and applies voice commands to text
public struct VoiceCommandParser {
    /// Parse voice commands embedded in text
    public static func parse(_ text: String) -> String {
        var result = text

        // Handle punctuation commands
        result = handlePunctuationCommands(result)

        // Handle formatting commands
        result = handleFormattingCommands(result)

        // Handle structure commands
        result = handleStructureCommands(result)

        return result
    }

    // MARK: - Command Handlers

    private static func handlePunctuationCommands(_ text: String) -> String {
        var result = text

        // Period command - consume preceding space
        result = result.replacingOccurrences(
            of: "\\s*\\b(period|full stop)\\b",
            with: ".",
            options: [.regularExpression, .caseInsensitive]
        )

        // Comma command - consume preceding space
        result = result.replacingOccurrences(
            of: "\\s*\\b(comma)\\b",
            with: ",",
            options: [.regularExpression, .caseInsensitive]
        )

        // Question mark command - consume preceding space
        result = result.replacingOccurrences(
            of: "\\s*\\b(question mark)\\b",
            with: "?",
            options: [.regularExpression, .caseInsensitive]
        )

        // Exclamation command - consume preceding space
        result = result.replacingOccurrences(
            of: "\\s*\\b(exclamation mark|exclamation)\\b",
            with: "!",
            options: [.regularExpression, .caseInsensitive]
        )

        // Colon command - consume preceding space
        result = result.replacingOccurrences(
            of: "\\s*\\b(colon)\\b",
            with: ":",
            options: [.regularExpression, .caseInsensitive]
        )

        // Semicolon command - consume preceding space
        result = result.replacingOccurrences(
            of: "\\s*\\b(semicolon)\\b",
            with: ";",
            options: [.regularExpression, .caseInsensitive]
        )

        return result
    }

    private static func handleFormattingCommands(_ text: String) -> String {
        var result = text

        // Capitalize word
        let capitalizePattern = "capitalize\\s+([\\w]+)"
        if let regex = try? NSRegularExpression(pattern: capitalizePattern, options: .caseInsensitive) {
            let matches = regex.matches(
                in: result,
                range: NSRange(result.startIndex..., in: result)
            )
            for match in matches.reversed() {
                if let wordRange = Range(match.range(at: 1), in: result) {
                    let word = String(result[wordRange])
                    let capitalized = word.prefix(1).uppercased() + word.dropFirst()
                    result.replaceSubrange(wordRange, with: capitalized)
                }
            }
        }

        // Uppercase word
        let uppercasePattern = "uppercase\\s+([\\w]+)"
        if let regex = try? NSRegularExpression(pattern: uppercasePattern, options: .caseInsensitive) {
            let matches = regex.matches(
                in: result,
                range: NSRange(result.startIndex..., in: result)
            )
            for match in matches.reversed() {
                if let wordRange = Range(match.range(at: 1), in: result) {
                    let word = String(result[wordRange])
                    result.replaceSubrange(wordRange, with: word.uppercased())
                }
            }
        }

        return result
    }

    private static func handleStructureCommands(_ text: String) -> String {
        var result = text

        // New paragraph command (must come before new line to match "new paragraph" first)
        result = result.replacingOccurrences(
            of: "\\s*\\b(new paragraph)\\b\\s*",
            with: "\n\n",
            options: [.regularExpression, .caseInsensitive]
        )

        // New line command
        result = result.replacingOccurrences(
            of: "\\s*\\b(new line|next line)\\b\\s*",
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )

        return result
    }
}

// MARK: - Post-Processing Pipeline

/// Full pipeline combining voice commands and optional LLM post-processing
public actor PostProcessingPipeline {
    private let postProcessor: TextPostProcessor?
    private var logger: Logger?

    /// Initialize the pipeline with optional post-processor
    public init(postProcessor: TextPostProcessor? = nil) {
        self.postProcessor = postProcessor
        self.logger = Logger(subsystem: "com.soundvibe.postprocessing", category: "Pipeline")
    }

    /// Process text through the pipeline
    /// - Parameters:
    ///   - text: Raw transcription text
    ///   - settings: Settings containing post-processing preferences
    /// - Returns: Final processed text ready for insertion
    public func process(_ text: String, settings: PostProcessingSettings) async throws -> String {
        logger?.debug("Pipeline: Starting text processing")

        // Step 1: Apply voice command parsing
        let commandParsed = VoiceCommandParser.parse(text)
        logger?.debug("Pipeline: Voice commands parsed")

        // Step 2: Apply LLM post-processing if enabled
        guard settings.postProcessingEnabled else {
            logger?.debug("Pipeline: Post-processing disabled, returning command-parsed text")
            return commandParsed
        }

        guard let postProcessor = postProcessor else {
            logger?.warning("Pipeline: Post-processing enabled but no processor available")
            return commandParsed
        }

        guard postProcessor.isAvailable else {
            logger?.warning("Pipeline: Post-processor not available, skipping LLM processing")
            return commandParsed
        }

        do {
            let mode = settings.postProcessingMode
            logger?.debug("Pipeline: Starting LLM post-processing with mode: \(mode.rawValue)")

            let processed = try await postProcessor.process(commandParsed, mode: mode)
            logger?.debug("Pipeline: LLM post-processing completed successfully")

            return processed
        } catch {
            // Graceful degradation: return voice-command-parsed text if LLM fails
            logger?.error(
                "Pipeline: LLM processing failed, returning command-parsed text. Error: \(error.localizedDescription)"
            )

            // Return the voice-command-parsed text with a warning indicator
            return commandParsed
        }
    }
}

// MARK: - Post-Processing Settings Protocol

/// Protocol for settings needed by the post-processing pipeline
public protocol PostProcessingSettings {
    /// Whether post-processing is enabled
    var postProcessingEnabled: Bool { get }

    /// The post-processing mode to use
    var postProcessingMode: PostProcessingMode { get }

    /// Custom prompt for custom mode (if set)
    var customPostProcessingPrompt: String { get }
}

// MARK: - Logger (Compatibility)

#if os(macOS)
import os.log

/// Logger wrapper for consistent logging across platforms
public struct Logger {
    private let osLog: os.Logger

    public init(subsystem: String, category: String) {
        self.osLog = os.Logger(subsystem: subsystem, category: category)
    }

    public func debug(_ message: String) {
        osLog.debug("\(message)")
    }

    public func info(_ message: String) {
        osLog.info("\(message)")
    }

    public func warning(_ message: String) {
        osLog.warning("\(message)")
    }

    public func error(_ message: String) {
        osLog.error("\(message)")
    }
}
#else
/// Cross-platform logger for testing on Linux
public struct Logger {
    private let subsystem: String
    private let category: String

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }

    public func debug(_ message: String) {
        print("[DEBUG] [\(category)] \(message)")
    }

    public func info(_ message: String) {
        print("[INFO] [\(category)] \(message)")
    }

    public func warning(_ message: String) {
        print("[WARNING] [\(category)] \(message)")
    }

    public func error(_ message: String) {
        print("[ERROR] [\(category)] \(message)")
    }
}
#endif

// MARK: - Default Settings Implementation

/// Default implementation of PostProcessingSettings for testing
public struct DefaultSettingsManager: PostProcessingSettings {
    public let postProcessingEnabled: Bool
    public let postProcessingMode: PostProcessingMode
    public let customPostProcessingPrompt: String

    public init(
        postProcessingEnabled: Bool = false,
        postProcessingMode: PostProcessingMode = .clean,
        customPostProcessingPrompt: String = ""
    ) {
        self.postProcessingEnabled = postProcessingEnabled
        self.postProcessingMode = postProcessingMode
        self.customPostProcessingPrompt = customPostProcessingPrompt
    }
}

// MARK: - SettingsManager Conformance

/// Extend the canonical SettingsManager to conform to PostProcessingSettings
extension SettingsManager: PostProcessingSettings {}
