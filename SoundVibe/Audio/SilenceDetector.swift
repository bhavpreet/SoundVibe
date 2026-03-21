import Foundation

// MARK: - Silence Detector

/// Detects continuous silence in the audio stream and tracks
/// how long silence has persisted.
///
/// The orchestrator polls audio levels and feeds them to this
/// actor. When the level stays below a threshold for an extended
/// period, the detector flags it so the UI can warn the user.
actor SilenceDetector {

    // MARK: - Properties

    /// Timestamp when silence started (nil if not silent)
    private var silenceStartTime: Date?

    /// Whether we are currently in a silent stretch
    private(set) var isSilent: Bool = false

    /// How long the current silence has lasted (seconds)
    var silenceDuration: TimeInterval {
        guard let start = silenceStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Public Methods

    /// Updates the detector with a new audio level sample.
    ///
    /// - Parameters:
    ///   - level: Normalized RMS level (0.0–1.0).
    ///   - threshold: Level below which audio is considered silent.
    /// - Returns: `true` if currently in a silent stretch.
    @discardableResult
    func update(level: Float, threshold: Float = 0.05) -> Bool {
        if level < threshold {
            if silenceStartTime == nil {
                silenceStartTime = Date()
            }
            isSilent = true
        } else {
            silenceStartTime = nil
            isSilent = false
        }
        return isSilent
    }

    /// Resets the detector state.
    func reset() {
        silenceStartTime = nil
        isSilent = false
    }
}
