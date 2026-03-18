import Foundation

/// Represents the different Whisper model sizes available for transcription
public enum WhisperModelSize: String, Codable, CaseIterable {
    case tiny
    case base
    case small
    case medium
    case largeV3 = "large-v3"

    var displayName: String {
        switch self {
        case .tiny:
            return "Tiny (39MB) - Fastest, least accurate"
        case .base:
            return "Base (140MB) - Fast, good for real-time"
        case .small:
            return "Small (466MB) - Balanced speed and accuracy"
        case .medium:
            return "Medium (1.5GB) - High accuracy, slower"
        case .largeV3:
            return "Large V3 (2.9GB) - Highest accuracy"
        }
    }

    var fileName: String {
        switch self {
        case .tiny:
            return "ggml-tiny.bin"
        case .base:
            return "ggml-base.bin"
        case .small:
            return "ggml-small.bin"
        case .medium:
            return "ggml-medium.bin"
        case .largeV3:
            return "ggml-large-v3.bin"
        }
    }

    var downloadURL: URL {
        let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"
        return URL(string: baseURL + fileName)!
    }

    /// Size on disk in bytes (approximate)
    var diskSize: Int {
        switch self {
        case .tiny:
            return 39_000_000
        case .base:
            return 140_000_000
        case .small:
            return 466_000_000
        case .medium:
            return 1_500_000_000
        case .largeV3:
            return 2_900_000_000
        }
    }

    /// Approximate number of parameters
    var parameterCount: Int {
        switch self {
        case .tiny:
            return 39_000_000
        case .base:
            return 72_000_000
        case .small:
            return 244_000_000
        case .medium:
            return 769_000_000
        case .largeV3:
            return 1_550_000_000
        }
    }

    /// Relative speed compared to base model (1.0 = same speed as base)
    var relativeSpeed: Double {
        switch self {
        case .tiny:
            return 32.0
        case .base:
            return 1.0
        case .small:
            return 0.5
        case .medium:
            return 0.25
        case .largeV3:
            return 0.1
        }
    }

    /// Word Error Rate (WER) on common benchmarks (lower is better)
    var wordErrorRate: Double {
        switch self {
        case .tiny:
            return 0.38
        case .base:
            return 0.12
        case .small:
            return 0.08
        case .medium:
            return 0.05
        case .largeV3:
            return 0.04
        }
    }

    /// Checks if the model is already downloaded on disk
    var isDownloaded: Bool {
        let modelPath = Self.modelsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }

    /// The directory where all Whisper models are stored
    static var modelsDirectory: URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupportURL.appendingPathComponent("SoundVibe").appendingPathComponent("Models")
    }

    /// Ensures the models directory exists
    static func ensureModelsDirectoryExists() throws {
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
}
