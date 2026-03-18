import Foundation

#if os(macOS)
import AppKit
#endif

// MARK: - Post-Processing Mode

public enum PostProcessingMode: String, Codable, CaseIterable, Hashable {
    case clean
    case formal
    case concise
    case custom

    public var description: String {
        switch self {
        case .clean: return "Clean"
        case .formal: return "Formal"
        case .concise: return "Concise"
        case .custom: return "Custom"
        }
    }

    var displayName: String {
        switch self {
        case .clean: return "Clean (Remove filler words)"
        case .formal: return "Formal (Business tone)"
        case .concise: return "Concise (Remove redundancy)"
        case .custom: return "Custom (Use custom prompt)"
        }
    }

    var defaultPrompt: String {
        switch self {
        case .clean:
            return "Remove filler words like 'um', 'uh', 'like', "
                + "'you know' while preserving meaning."
        case .formal:
            return "Rewrite this with formal business language "
                + "and proper grammar."
        case .concise:
            return "Condense this to the essential information, "
                + "removing redundancy."
        case .custom:
            return ""
        }
    }
}

// MARK: - Post-Processing Errors

public enum PostProcessingError: LocalizedError {
    case modelNotLoaded
    case processingFailed(String)
    case modelLoadFailed(String)
    case unsupportedHardware
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Language model is not loaded."
        case .processingFailed(let reason):
            return "Text processing failed: \(reason)"
        case .modelLoadFailed(let reason):
            return "Failed to load language model: \(reason)"
        case .unsupportedHardware:
            return "This device does not support local LLM inference."
        case .cancelled:
            return "Processing was cancelled."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .modelNotLoaded:
            return "Enable post-processing in Settings to download."
        case .processingFailed:
            return "Try processing again."
        case .modelLoadFailed:
            return "Check your network connection and try again."
        case .unsupportedHardware:
            return "Upgrade to Apple Silicon Mac."
        case .cancelled:
            return "Try again."
        }
    }
}

// MARK: - Protocol

public protocol TextPostProcessor: AnyObject, Sendable {
    func process(
        _ text: String, mode: PostProcessingMode
    ) async throws -> String
    var isAvailable: Bool { get }
    var isProcessing: Bool { get }
}

// MARK: - Local Text Post-Processor

/// Post-processor that applies rule-based text transformations.
/// Provides real text cleanup without requiring an LLM model.
///
/// NOTE: Real MLX LLM integration requires an Xcode project build
/// to properly bundle Metal shader libraries. This rule-based
/// processor provides useful cleanup until that is set up.
public actor MLXPostProcessor: TextPostProcessor {

    private var modelLoaded: Bool = false
    private var processingInProgress: Bool = false

    public nonisolated var isAvailable: Bool {
        #if os(macOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine.contains("arm64")
        #else
        return false
        #endif
    }

    public nonisolated var isProcessing: Bool { false }

    public init() {}

    public func loadModel() async throws {
        guard isAvailable else {
            throw PostProcessingError.unsupportedHardware
        }
        // Rule-based processor is always "loaded"
        modelLoaded = true
    }

    public func loadModel(named _: String) async throws {
        modelLoaded = true
    }

    public func unloadModel() {
        modelLoaded = false
    }

    public func process(
        _ text: String,
        mode: PostProcessingMode
    ) async throws -> String {
        guard modelLoaded else {
            throw PostProcessingError.modelNotLoaded
        }

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return text }

        processingInProgress = true
        defer { processingInProgress = false }

        switch mode {
        case .clean:
            return cleanText(trimmed)
        case .formal:
            return formalizeText(trimmed)
        case .concise:
            return conciseText(trimmed)
        case .custom:
            return trimmed
        }
    }

    // MARK: - Rule-Based Transforms

    private func cleanText(_ text: String) -> String {
        let fillers = [
            "um", "uh", "like", "you know", "basically",
            "actually", "literally", "so basically",
        ]
        var cleaned = text
        for filler in fillers {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: filler))\\b\\s*"
            cleaned = cleaned.replacingOccurrences(
                of: pattern, with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        if !cleaned.isEmpty {
            cleaned = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private func formalizeText(_ text: String) -> String {
        var formal = text
        let subs = [
            "gonna": "going to", "wanna": "want to",
            "kinda": "kind of", "sorta": "sort of",
            "yeah": "yes", "nope": "no", "gotta": "have to",
        ]
        for (informal, replacement) in subs {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: informal))\\b"
            formal = formal.replacingOccurrences(
                of: pattern, with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        if !formal.isEmpty {
            formal = formal.prefix(1).uppercased() + formal.dropFirst()
        }
        return formal.trimmingCharacters(in: .whitespaces)
    }

    private func conciseText(_ text: String) -> String {
        let redundant = [
            "I mean": "", "you know": "", "kind of": "",
            "sort of": "", "in order to": "to",
            "at this point in time": "now",
            "due to the fact that": "because",
        ]
        var concise = text
        for (phrase, replacement) in redundant {
            concise = concise.replacingOccurrences(
                of: phrase, with: replacement,
                options: .caseInsensitive
            )
        }
        return concise.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Mock Post-Processor (for Testing)

public actor MockPostProcessor: TextPostProcessor {
    private var mockModelLoaded: Bool = false
    private var mockProcessingInProgress: Bool = false

    public nonisolated var isAvailable: Bool { true }
    public nonisolated var isProcessing: Bool { false }

    public init(modelLoaded: Bool = false) {
        self.mockModelLoaded = modelLoaded
    }

    public func loadModel(named _: String) async throws {
        mockModelLoaded = true
    }

    public func unloadModel() {
        mockModelLoaded = false
    }

    public func process(
        _ text: String,
        mode: PostProcessingMode
    ) async throws -> String {
        guard mockModelLoaded else {
            throw PostProcessingError.modelNotLoaded
        }

        mockProcessingInProgress = true
        defer { mockProcessingInProgress = false }

        try await Task.sleep(nanoseconds: 100_000_000)

        return "[\(mode.rawValue)] \(text)"
    }
}
