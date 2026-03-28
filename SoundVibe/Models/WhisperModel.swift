import Foundation

/// Represents the different Whisper model sizes available for transcription
public enum WhisperModelSize: String, Codable, CaseIterable {
  case tiny
  case base
  case small
  case medium
  case largeV3Turbo = "large-v3-turbo"
  case largeV3 = "large-v3"

  /// The WhisperKit model identifier used for downloading and loading.
  /// Maps to the folder name in the argmaxinc/whisperkit-coreml HuggingFace repo.
  /// Note: the turbo variant uses an underscore (`_turbo`) not a hyphen in the hub.
  var whisperKitIdentifier: String {
    switch self {
    case .largeV3Turbo:
      return "openai_whisper-large-v3_turbo"
    default:
      return "openai_whisper-\(rawValue)"
    }
  }

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
    case .largeV3Turbo:
      return "Large V3 Turbo (809MB) - Near-best accuracy, fast"
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
    case .largeV3Turbo:
      return "ggml-large-v3-turbo.bin"
    case .largeV3:
      return "ggml-large-v3.bin"
    }
  }

  var downloadURL: URL {
    let baseURL =
      "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"
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
    case .largeV3Turbo:
      return 809_000_000
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
    case .largeV3Turbo:
      return 809_000_000
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
    case .largeV3Turbo:
      return 0.4
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
    case .largeV3Turbo:
      return 0.021
    case .largeV3:
      return 0.04
    }
  }

  /// Checks if the model is already downloaded on disk
  /// (WhisperKit uses folder structure, not single .bin file)
  var isDownloaded: Bool {
    // WhisperKit downloads to:
    // modelsDirectory/{whisperKitIdentifier}/
    let folderPath = Self.modelsDirectory
      .appendingPathComponent(whisperKitIdentifier)

    // Check if folder exists
    guard FileManager.default.fileExists(
      atPath: folderPath.path
    ) else {
      return false
    }

    // Verify essential files are present
    return Self.requiredModelFiles.allSatisfy { file in
      let filePath = folderPath
        .appendingPathComponent(file)
      return FileManager.default.fileExists(
        atPath: filePath.path
      )
    }
  }

  /// Required files that must be present in a valid
  /// WhisperKit model folder.
  /// WhisperKit CoreML models use separate .mlmodelc bundles
  /// for each component — not a single "model.mlmodelc".
  /// Tokenizers are managed separately by WhisperKit via the
  /// tokenizerFolder parameter, so tokenizer.json is not
  /// required inside the model folder.
  static let requiredModelFiles = [
    "config.json",
    "MelSpectrogram.mlmodelc",
    "AudioEncoder.mlmodelc",
    "TextDecoder.mlmodelc",
  ]

  /// The directory where all Whisper models are stored
  static var modelsDirectory: URL {
    let appSupportURL = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0]
    return appSupportURL
      .appendingPathComponent("SoundVibe")
      .appendingPathComponent("Models")
  }

  /// Ensures the models directory exists
  static func ensureModelsDirectoryExists() throws {
    try FileManager.default.createDirectory(
      at: modelsDirectory,
      withIntermediateDirectories: true
    )
  }

  // MARK: - Speed & Accuracy Ratings (B1)

  /// Speed rating as lightning bolt icons (1-5 ⚡)
  var speedRating: String {
    switch self {
    case .tiny:
      return "⚡⚡⚡⚡⚡"
    case .base:
      return "⚡⚡⚡⚡"
    case .small:
      return "⚡⚡⚡"
    case .medium:
      return "⚡⚡"
    case .largeV3Turbo:
      return "⚡⚡⚡"
    case .largeV3:
      return "⚡"
    }
  }

  /// Accuracy rating as star icons (1-5 ⭐)
  var accuracyRating: String {
    switch self {
    case .tiny:
      return "⭐"
    case .base:
      return "⭐⭐"
    case .small:
      return "⭐⭐⭐"
    case .medium:
      return "⭐⭐⭐⭐"
    case .largeV3Turbo:
      return "⭐⭐⭐⭐⭐"
    case .largeV3:
      return "⭐⭐⭐⭐⭐"
    }
  }

  /// Numeric speed rating (1-5, higher is faster)
  var speedRatingValue: Int {
    switch self {
    case .tiny: return 5
    case .base: return 4
    case .small: return 3
    case .medium: return 2
    case .largeV3Turbo: return 3
    case .largeV3: return 1
    }
  }

  /// Numeric accuracy rating (1-5, higher is more accurate)
  var accuracyRatingValue: Int {
    switch self {
    case .tiny: return 1
    case .base: return 2
    case .small: return 3
    case .medium: return 4
    case .largeV3Turbo: return 5
    case .largeV3: return 5
    }
  }

  // MARK: - Latency Estimation (B7)

  /// Estimated transcription latency for a 10-second audio clip
  /// on Apple Silicon (Metal GPU acceleration)
  var estimatedLatencyAppleSilicon: TimeInterval {
    switch self {
    case .tiny:
      return 0.3
    case .base:
      return 0.5
    case .small:
      return 1.0
    case .medium:
      return 2.5
    case .largeV3Turbo:
      return 2.0
    case .largeV3:
      return 5.0
    }
  }

  /// Estimated transcription latency for a 10-second audio clip
  /// on Intel Mac (CPU only, no GPU acceleration)
  var estimatedLatencyIntel: TimeInterval {
    switch self {
    case .tiny:
      return 1.5
    case .base:
      return 3.0
    case .small:
      return 6.0
    case .medium:
      return 15.0
    case .largeV3Turbo:
      return 10.0
    case .largeV3:
      return 30.0
    }
  }

  /// Returns estimated latency based on current device architecture
  func estimatedLatency() -> TimeInterval {
    if DeviceProfiler.isAppleSilicon {
      return estimatedLatencyAppleSilicon
    } else {
      return estimatedLatencyIntel
    }
  }

  /// Human-readable latency description for the current device
  var latencyDescription: String {
    let latency = estimatedLatency()
    if latency < 1.0 {
      return "Est. latency: < 1 second"
    } else if latency < 2.0 {
      return "Est. latency: ~1 second"
    } else if latency < 5.0 {
      return "Est. latency: ~\(Int(latency)) seconds"
    } else if latency < 10.0 {
      return "Est. latency: ~\(Int(latency)) seconds"
    } else {
      return "Est. latency: ~\(Int(latency))+ seconds"
    }
  }

  /// Human-readable disk size description
  var diskSizeDescription: String {
    if diskSize >= 1_000_000_000 {
      let gb = Double(diskSize) / 1_000_000_000.0
      return String(format: "%.1f GB", gb)
    } else {
      let mb = Double(diskSize) / 1_000_000.0
      return String(format: "%.0f MB", mb)
    }
  }
}
