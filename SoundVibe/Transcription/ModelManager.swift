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

/// Errors related to model management
public enum ModelManagerError: LocalizedError {
    case downloadFailed(reason: String)
    case checksumMismatch
    case diskSpaceInsufficient
    case modelNotFound
    case deletionFailed(reason: String)
    case invalidModelPath

    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Model download failed: \(reason)"
        case .checksumMismatch:
            return "Model checksum verification failed - file may be corrupted"
        case .diskSpaceInsufficient:
            return "Insufficient disk space to download model"
        case .modelNotFound:
            return "Model file not found"
        case .deletionFailed(let reason):
            return "Failed to delete model: \(reason)"
        case .invalidModelPath:
            return "Invalid model file path"
        }
    }
}

// MARK: - URLSessionDownloadDelegate

#if os(macOS)
/// Delegate for tracking download progress
private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var progressHandler: ((Double) -> Void)?
    var completion: ((URL?, Error?) -> Void)?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progressHandler?(progress)
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

    @Published public private(set) var availableModels: [WhisperModelInfo] = []
    @Published public private(set) var downloadProgress: [WhisperModelSize: Double] = [:]
    @Published public private(set) var activeModel: WhisperModelSize?

    // MARK: - Private Properties

    #if os(macOS)
    private var session: URLSession!
    private var downloadDelegates: [WhisperModelSize: DownloadDelegate] = [:]
    private var downloadTasks: [WhisperModelSize: URLSessionDownloadTask] = [:]
    #endif

    private let fileManager = FileManager.default
    private let modelsDirectoryUrl: URL

    // MARK: - Initialization

    public override init() {
        // Set up models directory: ~/Library/Application Support/SoundVibe/Models/
        let appSupportUrl = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        self.modelsDirectoryUrl = appSupportUrl.appendingPathComponent("SoundVibe/Models")

        super.init()

        // Create models directory if it doesn't exist
        try? fileManager.createDirectory(
            at: modelsDirectoryUrl,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Initialize session
        #if os(macOS)
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 3600 // 1 hour timeout for large downloads
        self.session = URLSession(configuration: config)
        #endif

        // Load available models
        self.availableModels = WhisperModelSize.allCases.map { WhisperModelInfo(size: $0) }

        // Load active model from preferences
        if let savedModelRaw = UserDefaults.standard.string(forKey: "activeWhisperModel"),
           let savedModel = WhisperModelSize(rawValue: savedModelRaw) {
            self.activeModel = savedModel
        }
    }

    // MARK: - Public Methods

    /// Get the local file path for a model
    public func modelPath(for model: WhisperModelSize) -> URL {
        modelsDirectoryUrl.appendingPathComponent("ggml-\(model.rawValue).bin")
    }

    /// Check if a model is already downloaded
    public func isModelDownloaded(_ model: WhisperModelSize) -> Bool {
        let path = modelPath(for: model)
        return fileManager.fileExists(atPath: path.path)
    }

    /// Download a model from HuggingFace with progress tracking
    /// - Parameter model: The model size to download
    public func downloadModel(_ model: WhisperModelSize) async throws {
        // Check disk space
        let availableSpace = try getAvailableDiskSpace()
        guard availableSpace > UInt64(model.diskSize) * 2 else { // 2x for safety margin
            throw ModelManagerError.diskSpaceInsufficient
        }

        // Skip if already downloading
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
        #endif
    }

    /// Delete a downloaded model
    public func deleteModel(_ model: WhisperModelSize) throws {
        let path = modelPath(for: model)
        guard fileManager.fileExists(atPath: path.path) else {
            throw ModelManagerError.modelNotFound
        }

        do {
            try fileManager.removeItem(at: path)
            if activeModel == model {
                activeModel = nil
                UserDefaults.standard.removeObject(forKey: "activeWhisperModel")
            }
        } catch {
            throw ModelManagerError.deletionFailed(reason: error.localizedDescription)
        }
    }

    /// Set the active model for transcription
    public func setActiveModel(_ model: WhisperModelSize) throws {
        guard isModelDownloaded(model) else {
            throw ModelManagerError.modelNotFound
        }
        activeModel = model
        UserDefaults.standard.set(model.rawValue, forKey: "activeWhisperModel")
    }

    // MARK: - Private Methods

    #if os(macOS)
    private func performDownload(_ model: WhisperModelSize) async throws {
        let modelInfo = WhisperModelInfo(size: model)
        let destinationUrl = modelPath(for: model)

        // Create delegate for progress tracking
        let delegate = DownloadDelegate()
        downloadDelegates[model] = delegate

        return try await withCheckedThrowingContinuation { continuation in
            delegate.progressHandler = { [weak self] progress in
                self?.downloadProgress[model] = progress
            }

            delegate.completion = { [weak self] location, error in
                self?.downloadTasks.removeValue(forKey: model)

                if let error = error {
                    continuation.resume(throwing: ModelManagerError.downloadFailed(reason: error.localizedDescription))
                    return
                }

                guard let location = location else {
                    continuation.resume(throwing: ModelManagerError.downloadFailed(reason: "Unknown error"))
                    return
                }

                do {
                    // Move to final location
                    try? FileManager.default.removeItem(at: destinationUrl)
                    try FileManager.default.moveItem(at: location, to: destinationUrl)

                    self?.downloadProgress[model] = 1.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.downloadProgress.removeValue(forKey: model)
                    }

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            let downloadTask = session.downloadTask(with: modelInfo.downloadUrl)
            downloadTasks[model] = downloadTask
            downloadTask.resume()
        }
    }
    #endif

    private func getAvailableDiskSpace() throws -> UInt64 {
        #if os(macOS)
        let attributes = try fileManager.attributesOfFileSystem(forPath: modelsDirectoryUrl.path)
        guard let freeSize = attributes[.systemFreeSize] as? UInt64 else {
            throw ModelManagerError.invalidModelPath
        }
        return freeSize
        #else
        return UInt64.max
        #endif
    }
}
