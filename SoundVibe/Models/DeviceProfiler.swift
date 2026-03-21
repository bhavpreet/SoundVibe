import Foundation

#if os(macOS)
import IOKit

// MARK: - Device Profile

/// Represents the hardware profile of the current device
public struct DeviceProfile {
  /// Total physical RAM in bytes
  let totalRAM: UInt64

  /// Total RAM in gigabytes (rounded, binary: 1 GiB = 1024³)
  var totalRAMGB: Int {
    Int(totalRAM / (1024 * 1024 * 1024))
  }

  /// Whether the device has Apple Silicon (ARM64)
  let isAppleSilicon: Bool

  /// Number of CPU cores (performance + efficiency)
  let cpuCoreCount: Int

  /// Available disk space in bytes
  let availableDiskSpace: UInt64

  /// Available disk space in gigabytes (decimal: 1 GB = 10⁹)
  var availableDiskSpaceGB: Double {
    Double(availableDiskSpace) / 1_000_000_000.0
  }

  /// Human-readable RAM description
  var ramDescription: String {
    "\(totalRAMGB) GB"
  }

  /// Human-readable disk space description
  var diskSpaceDescription: String {
    String(format: "%.1f GB", availableDiskSpaceGB)
  }

  /// Human-readable chip description
  var chipDescription: String {
    isAppleSilicon ? "Apple Silicon" : "Intel"
  }
}

// MARK: - Device Profiler

/// Detects hardware characteristics for model recommendations
public struct DeviceProfiler {

  // MARK: - Static Properties

  /// Whether the current device runs Apple Silicon
  public static var isAppleSilicon: Bool {
    #if arch(arm64)
    return true
    #else
    return false
    #endif
  }

  /// Total physical RAM in bytes
  public static var totalRAM: UInt64 {
    ProcessInfo.processInfo.physicalMemory
  }

  /// Total RAM in gigabytes
  public static var totalRAMGB: Int {
    Int(totalRAM / (1024 * 1024 * 1024))
  }

  /// Number of active processor cores
  public static var cpuCoreCount: Int {
    ProcessInfo.processInfo.activeProcessorCount
  }

  /// Available disk space in bytes at the models directory
  public static var availableDiskSpace: UInt64 {
    let fileManager = FileManager.default
    let modelsDir = WhisperModelSize.modelsDirectory

    // Ensure directory exists for the check
    try? fileManager.createDirectory(
      at: modelsDir,
      withIntermediateDirectories: true
    )

    guard
      let attributes = try? fileManager.attributesOfFileSystem(
        forPath: modelsDir.path
      ),
      let freeSize = attributes[.systemFreeSize] as? UInt64
    else {
      return 0
    }
    return freeSize
  }

  // MARK: - Profile Detection

  /// Builds a complete device profile snapshot
  public static func detectProfile() -> DeviceProfile {
    DeviceProfile(
      totalRAM: totalRAM,
      isAppleSilicon: isAppleSilicon,
      cpuCoreCount: cpuCoreCount,
      availableDiskSpace: availableDiskSpace
    )
  }

  // MARK: - Model Recommendation (B2)

  /// Recommends the best Whisper model based on device capabilities
  ///
  /// Recommendation logic:
  /// - < 8 GB RAM → Base (lightweight, fast)
  /// - 8-16 GB RAM → Small (balanced)
  /// - 16-32 GB RAM → Medium (high accuracy)
  /// - 32+ GB RAM → Large (best accuracy)
  ///
  /// Intel Macs are capped at Small due to no GPU acceleration
  public static func recommendedModel() -> WhisperModelSize {
    let ramGB = totalRAMGB

    // Intel Macs: cap at Small (no Metal GPU acceleration)
    if !isAppleSilicon {
      if ramGB < 8 {
        return .base
      } else {
        return .small
      }
    }

    // Apple Silicon with GPU acceleration
    if ramGB < 8 {
      return .base
    } else if ramGB < 16 {
      return .small
    } else if ramGB < 32 {
      return .medium
    } else {
      return .largeV3
    }
  }

  /// Returns a recommendation badge string for a given model
  public static func recommendationBadge(
    for model: WhisperModelSize
  ) -> String? {
    if model == recommendedModel() {
      return "Recommended"
    }
    return nil
  }

  /// Checks if a model download would fit on disk, with safety margin
  /// - Parameter model: The model to check
  /// - Returns: true if enough disk space is available
  public static func hasSufficientDiskSpace(
    for model: WhisperModelSize
  ) -> Bool {
    // Require 2x model size as safety margin
    let requiredSpace = UInt64(model.diskSize) * 2
    return availableDiskSpace >= requiredSpace
  }

  /// Returns a formatted string showing required vs available space
  public static func diskSpaceReport(
    for model: WhisperModelSize
  ) -> String {
    let required = Double(model.diskSize) / 1_000_000_000.0
    let available = Double(availableDiskSpace) / 1_000_000_000.0
    return String(
      format: "Required: %.1f GB • Available: %.1f GB",
      required,
      available
    )
  }
}

#endif
