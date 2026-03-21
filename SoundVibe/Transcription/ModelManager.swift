import Foundation

#if os(macOS)
import AppKit
import CommonCrypto
#endif

// MARK: - Types

/// Metadata about a Whisper model (view model wrapper around WhisperModelSize)
public struct WhisperModelInfo: Identifiable {
  public let id: WhisperModelSize
  public let name: String
  public let sizeDescription: String
  public let fileSize: Int
  public let downloadUrl: URL

  init(size: WhisperModelSize) {
    self.id = size
    self.name = "Whisper \(size.rawValue.capitalized)"
    self.sizeDescription = size.displayName
    self.fileSize = size.diskSize
    self.downloadUrl = size.downloadURL
  }
}

// MARK: - Download Progress (B3)

/// Detailed progress information for a model download
public struct ModelDownloadProgress {
  /// Download percentage (0.0 to 1.0)
  public let percentage: Double

  /// Download speed in bytes per second
  public let bytesPerSecond: Double

  /// Estimated time remaining in seconds
  public let estimatedTimeRemaining: TimeInterval?

  /// Total bytes downloaded so far
  public let bytesDownloaded: Int64

  /// Total expected bytes
  public let totalBytes: Int64

  /// Human-readable speed string (e.g., "12.5 MB/s")
  public var speedDescription: String {
    let mbPerSecond = bytesPerSecond / 1_000_000.0
    if mbPerSecond >= 1.0 {
      return String(format: "%.1f MB/s", mbPerSecond)
    } else {
      let kbPerSecond = bytesPerSecond / 1_000.0
      return String(format: "%.0f KB/s", kbPerSecond)
    }
  }

  /// Human-readable ETA string (e.g., "2m 30s")
  public var etaDescription: String {
    guard let eta = estimatedTimeRemaining, eta.isFinite else {
      return "Calculating..."
    }
    if eta < 60 {
      return String(format: "%.0fs remaining", eta)
    } else if eta < 3600 {
      let minutes = Int(eta) / 60
      let seconds = Int(eta) % 60
      return "\(minutes)m \(seconds)s remaining"
    } else {
      let hours = Int(eta) / 3600
      let minutes = (Int(eta) % 3600) / 60
      return "\(hours)h \(minutes)m remaining"
    }
  }
}

/// Errors related to model management
public enum ModelManagerError: LocalizedError {
  case downloadFailed(reason: String)
  case checksumMismatch
  case diskSpaceInsufficient(
    required: UInt64,
    available: UInt64
  )
  case modelNotFound
  case deletionFailed(reason: String)
  case invalidModelPath
  case cannotDeleteActiveModel

  public var errorDescription: String? {
    switch self {
    case .downloadFailed(let reason):
      return "Model download failed: \(reason)"
    case .checksumMismatch:
      return "Model checksum verification failed"
    case .diskSpaceInsufficient(let required, let available):
      let reqMB = Double(required) / 1_000_000.0
      let avMB = Double(available) / 1_000_000.0
      return String(
        format: "Insufficient disk space. Required: %.0f MB, "
          + "Available: %.0f MB",
        reqMB,
        avMB
      )
    case .modelNotFound:
      return "Model file not found"
    case .deletionFailed(let reason):
      return "Failed to delete model: \(reason)"
    case .invalidModelPath:
      return "Invalid model file path"
    case .cannotDeleteActiveModel:
      return "Cannot delete the active model. "
        + "Switch to a different model first."
    }
  }
}

// MARK: - URLSessionDownloadDelegate

#if os(macOS)
/// Delegate for tracking download progress with speed/ETA (B3)
private class DownloadDelegate: NSObject,
  URLSessionDownloadDelegate
{
  var progressHandler: ((ModelDownloadProgress) -> Void)?
  var completion: ((URL?, Error?) -> Void)?

  private var downloadStartTime: Date?
  private var lastBytesWritten: Int64 = 0
  private var lastUpdateTime: Date?

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    let now = Date()

    // Initialize timing on first callback
    if downloadStartTime == nil {
      downloadStartTime = now
      lastUpdateTime = now
      lastBytesWritten = 0
    }

    let progress = Double(totalBytesWritten)
      / Double(totalBytesExpectedToWrite)

    // Calculate speed using recent interval
    let elapsed = now.timeIntervalSince(
      lastUpdateTime ?? now
    )
    var speed: Double = 0
    if elapsed > 0.1 {
      let recentBytes = totalBytesWritten - lastBytesWritten
      speed = Double(recentBytes) / elapsed
      lastBytesWritten = totalBytesWritten
      lastUpdateTime = now
    }

    // Calculate ETA
    var eta: TimeInterval?
    if speed > 0 {
      let remaining = totalBytesExpectedToWrite
        - totalBytesWritten
      eta = Double(remaining) / speed
    }

    let downloadProgress = ModelDownloadProgress(
      percentage: progress,
      bytesPerSecond: speed,
      estimatedTimeRemaining: eta,
      bytesDownloaded: totalBytesWritten,
      totalBytes: totalBytesExpectedToWrite
    )

    DispatchQueue.main.async {
      self.progressHandler?(downloadProgress)
    }
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    completion?(location, nil)
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    if error != nil {
      completion?(nil, error)
    }
  }
}
#endif

// MARK: - ModelManager

/// Manages Whisper model downloads, storage, and lifecycle
@MainActor
public class ModelManager: NSObject, ObservableObject {
  // MARK: - Published Properties

  @Published public private(set) var availableModels:
    [WhisperModelInfo] = []
  @Published public private(set) var downloadProgress:
    [WhisperModelSize: Double] = [:]
  @Published public private(set) var detailedProgress:
    [WhisperModelSize: ModelDownloadProgress] = [:]
  @Published public private(set) var activeModel: WhisperModelSize?

  // MARK: - Private Properties

  #if os(macOS)
  private var session: URLSession!
  private var downloadDelegates:
    [WhisperModelSize: DownloadDelegate] = [:]
  private var downloadTasks:
    [WhisperModelSize: URLSessionDownloadTask] = [:]
  #endif

  private let fileManager = FileManager.default
  private let modelsDirectoryUrl: URL

  // MARK: - Initialization

  public override init() {
    let appSupportUrl = fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0]
    self.modelsDirectoryUrl = appSupportUrl
      .appendingPathComponent("SoundVibe/Models")

    super.init()

    try? fileManager.createDirectory(
      at: modelsDirectoryUrl,
      withIntermediateDirectories: true,
      attributes: nil
    )

    #if os(macOS)
    let config = URLSessionConfiguration.default
    config.waitsForConnectivity = true
    // 1 hour timeout for large downloads
    config.timeoutIntervalForResource = 3600
    self.session = URLSession(configuration: config)
    #endif

    self.availableModels = WhisperModelSize.allCases.map {
      WhisperModelInfo(size: $0)
    }

    if let savedRaw = UserDefaults.standard.string(
      forKey: "activeWhisperModel"
    ),
      let saved = WhisperModelSize(rawValue: savedRaw)
    {
      self.activeModel = saved
    }
  }

  // MARK: - Public Methods

  /// Get the local file path for a model
  public func modelPath(for model: WhisperModelSize) -> URL {
    modelsDirectoryUrl
      .appendingPathComponent("ggml-\(model.rawValue).bin")
  }

  /// Check if a model is already downloaded
  public func isModelDownloaded(
    _ model: WhisperModelSize
  ) -> Bool {
    let path = modelPath(for: model)
    return fileManager.fileExists(atPath: path.path)
  }

  /// Download a model with disk space check (B3, B4)
  public func downloadModel(
    _ model: WhisperModelSize
  ) async throws {
    // B4: Pre-download disk space check
    let availableSpace = try getAvailableDiskSpace()
    let requiredSpace = UInt64(model.diskSize) * 2
    guard availableSpace > requiredSpace else {
      throw ModelManagerError.diskSpaceInsufficient(
        required: UInt64(model.diskSize),
        available: availableSpace
      )
    }

    #if os(macOS)
    if downloadTasks[model] != nil {
      return
    }
    #endif

    try await performDownload(model)
  }

  /// Cancel an active download
  public func cancelDownload(_ model: WhisperModelSize) {
    #if os(macOS)
    downloadTasks[model]?.cancel()
    downloadTasks.removeValue(forKey: model)
    downloadDelegates.removeValue(forKey: model)
    downloadProgress.removeValue(forKey: model)
    detailedProgress.removeValue(forKey: model)
    #endif
  }

  /// Delete a downloaded model (B5)
  /// Cannot delete the currently active model
  public func deleteModel(
    _ model: WhisperModelSize
  ) throws {
    // B5: Prevent deleting the active model
    if activeModel == model {
      throw ModelManagerError.cannotDeleteActiveModel
    }

    let path = modelPath(for: model)
    guard fileManager.fileExists(atPath: path.path) else {
      throw ModelManagerError.modelNotFound
    }

    do {
      try fileManager.removeItem(at: path)
    } catch {
      throw ModelManagerError.deletionFailed(
        reason: error.localizedDescription
      )
    }
  }

  /// Set the active model for transcription
  public func setActiveModel(
    _ model: WhisperModelSize
  ) throws {
    guard isModelDownloaded(model) else {
      throw ModelManagerError.modelNotFound
    }
    activeModel = model
    UserDefaults.standard.set(
      model.rawValue,
      forKey: "activeWhisperModel"
    )
  }

  // MARK: - Downloaded Models Management (B5)

  /// Returns list of all downloaded model sizes
  public func downloadedModels() -> [WhisperModelSize] {
    WhisperModelSize.allCases.filter { isModelDownloaded($0) }
  }

  /// Total disk usage of all downloaded models in bytes
  public func totalDiskUsage() -> UInt64 {
    var total: UInt64 = 0
    for model in WhisperModelSize.allCases {
      let path = modelPath(for: model)
      if let attrs = try? fileManager.attributesOfItem(
        atPath: path.path
      ),
        let size = attrs[.size] as? UInt64
      {
        total += size
      }
    }
    return total
  }

  /// Human-readable summary of downloaded models
  /// e.g., "3 models • 2.1 GB used"
  public func downloadedModelsSummary() -> String {
    let models = downloadedModels()
    let count = models.count
    let totalBytes = totalDiskUsage()
    let totalGB = Double(totalBytes) / 1_000_000_000.0

    if count == 0 {
      return "No models downloaded"
    }

    if totalGB >= 1.0 {
      return String(
        format: "%d model%@ • %.1f GB used",
        count,
        count == 1 ? "" : "s",
        totalGB
      )
    } else {
      let totalMB = Double(totalBytes) / 1_000_000.0
      return String(
        format: "%d model%@ • %.0f MB used",
        count,
        count == 1 ? "" : "s",
        totalMB
      )
    }
  }

  /// File size on disk for a specific downloaded model
  public func actualFileSize(
    for model: WhisperModelSize
  ) -> UInt64? {
    let path = modelPath(for: model)
    guard
      let attrs = try? fileManager.attributesOfItem(
        atPath: path.path
      ),
      let size = attrs[.size] as? UInt64
    else {
      return nil
    }
    return size
  }

  /// Whether a download is currently in progress for a model
  public func isDownloading(
    _ model: WhisperModelSize
  ) -> Bool {
    #if os(macOS)
    return downloadTasks[model] != nil
    #else
    return false
    #endif
  }

  // MARK: - Private Methods

  #if os(macOS)
  private func performDownload(
    _ model: WhisperModelSize
  ) async throws {
    let modelInfo = WhisperModelInfo(size: model)
    let destinationUrl = modelPath(for: model)

    let delegate = DownloadDelegate()
    downloadDelegates[model] = delegate

    return try await withCheckedThrowingContinuation {
      continuation in
      delegate.progressHandler = { [weak self] progress in
        self?.downloadProgress[model] = progress.percentage
        self?.detailedProgress[model] = progress
      }

      delegate.completion = {
        [weak self] location, error in
        self?.downloadTasks.removeValue(forKey: model)

        if let error = error {
          continuation.resume(
            throwing: ModelManagerError.downloadFailed(
              reason: error.localizedDescription
            )
          )
          return
        }

        guard let location = location else {
          continuation.resume(
            throwing: ModelManagerError.downloadFailed(
              reason: "Unknown error"
            )
          )
          return
        }

        do {
          try? FileManager.default.removeItem(
            at: destinationUrl
          )
          try FileManager.default.moveItem(
            at: location,
            to: destinationUrl
          )

          self?.downloadProgress[model] = 1.0
          DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.5
          ) {
            self?.downloadProgress
              .removeValue(forKey: model)
            self?.detailedProgress
              .removeValue(forKey: model)
          }

          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }

      let downloadSession = URLSession(
        configuration: .default,
        delegate: delegate,
        delegateQueue: nil
      )
      let downloadTask = downloadSession.downloadTask(
        with: modelInfo.downloadUrl
      )
      downloadTasks[model] = downloadTask
      downloadTask.resume()
    }
  }
  #endif

  private func getAvailableDiskSpace() throws -> UInt64 {
    #if os(macOS)
    let attributes = try fileManager.attributesOfFileSystem(
      forPath: modelsDirectoryUrl.path
    )
    guard
      let freeSize = attributes[.systemFreeSize] as? UInt64
    else {
      throw ModelManagerError.invalidModelPath
    }
    return freeSize
    #else
    return UInt64.max
    #endif
  }
}
