import XCTest
@testable import SoundVibe

// MARK: - Device Profiler Tests (B2)

final class DeviceProfilerTests: XCTestCase {

  // MARK: - Device Profile Detection

  func testDeviceProfileDetectsRAM() {
    // Arrange & Act
    let profile = DeviceProfiler.detectProfile()

    // Assert — any real Mac has at least 4 GB
    XCTAssertGreaterThan(
      profile.totalRAM,
      0,
      "Total RAM should be positive"
    )
    XCTAssertGreaterThanOrEqual(
      profile.totalRAMGB,
      4,
      "Should detect at least 4 GB RAM on macOS"
    )
  }

  func testDeviceProfileDetectsCPUCores() {
    let profile = DeviceProfiler.detectProfile()
    XCTAssertGreaterThan(
      profile.cpuCoreCount,
      0,
      "CPU core count should be positive"
    )
  }

  func testDeviceProfileDetectsDiskSpace() {
    let profile = DeviceProfiler.detectProfile()
    XCTAssertGreaterThan(
      profile.availableDiskSpace,
      0,
      "Available disk space should be positive"
    )
  }

  func testDeviceProfileRAMDescription() {
    let profile = DeviceProfiler.detectProfile()
    XCTAssertTrue(
      profile.ramDescription.contains("GB"),
      "RAM description should contain 'GB'"
    )
  }

  func testDeviceProfileChipDescription() {
    let profile = DeviceProfiler.detectProfile()
    let desc = profile.chipDescription
    XCTAssertTrue(
      desc == "Apple Silicon" || desc == "Intel",
      "Chip description should be Apple Silicon or Intel"
    )
  }

  // MARK: - Model Recommendation Logic (B2)

  func testModelRecommendationReturnsValidModel() {
    // Arrange & Act
    let recommended = DeviceProfiler.recommendedModel()

    // Assert
    XCTAssertTrue(
      WhisperModelSize.allCases.contains(recommended),
      "Recommended model should be a valid model size"
    )
  }

  func testModelRecommendationLogic() {
    // The recommended model should be reasonable for
    // the current device — at minimum Base
    let recommended = DeviceProfiler.recommendedModel()
    let ramGB = DeviceProfiler.totalRAMGB

    if ramGB < 8 {
      XCTAssertEqual(
        recommended,
        .base,
        "< 8 GB RAM should recommend Base"
      )
    } else if !DeviceProfiler.isAppleSilicon {
      // Intel: capped at Small
      XCTAssertTrue(
        recommended == .base || recommended == .small,
        "Intel should recommend Base or Small"
      )
    } else {
      // Apple Silicon with >= 8 GB
      XCTAssertTrue(
        recommended.diskSize >= WhisperModelSize.small.diskSize,
        "Apple Silicon with >= 8 GB should recommend "
          + "at least Small"
      )
    }
  }

  func testRecommendationBadge() {
    let recommended = DeviceProfiler.recommendedModel()

    // Badge should exist for recommended model
    let badge = DeviceProfiler.recommendationBadge(
      for: recommended
    )
    XCTAssertEqual(
      badge,
      "Recommended",
      "Should show 'Recommended' for recommended model"
    )

    // Badge should be nil for non-recommended models
    for model in WhisperModelSize.allCases
    where model != recommended {
      let otherBadge = DeviceProfiler.recommendationBadge(
        for: model
      )
      XCTAssertNil(
        otherBadge,
        "Non-recommended model should not have a badge"
      )
    }
  }

  func testDiskSpaceCheckReturnsResult() {
    // Tiny is so small it should always pass
    let hasTinySpace = DeviceProfiler.hasSufficientDiskSpace(
      for: .tiny
    )
    XCTAssertTrue(
      hasTinySpace,
      "Should have enough space for Tiny model"
    )
  }

  func testDiskSpaceReportFormat() {
    let report = DeviceProfiler.diskSpaceReport(for: .base)
    XCTAssertTrue(
      report.contains("Required:"),
      "Report should contain 'Required:'"
    )
    XCTAssertTrue(
      report.contains("Available:"),
      "Report should contain 'Available:'"
    )
  }
}

// MARK: - Download Progress Tests (B3)

final class DownloadProgressTests: XCTestCase {

  func testDownloadProgressCalculation() {
    // Arrange
    let progress = ModelDownloadProgress(
      percentage: 0.5,
      bytesPerSecond: 10_000_000,
      estimatedTimeRemaining: 120.0,
      bytesDownloaded: 50_000_000,
      totalBytes: 100_000_000
    )

    // Assert
    XCTAssertEqual(
      progress.percentage,
      0.5,
      accuracy: 0.001,
      "Percentage should be 0.5"
    )
    XCTAssertEqual(
      progress.bytesPerSecond,
      10_000_000,
      accuracy: 1.0,
      "Speed should be 10 MB/s"
    )
  }

  func testDownloadProgressSpeedDescription() {
    // MB/s range
    let fast = ModelDownloadProgress(
      percentage: 0.5,
      bytesPerSecond: 12_500_000,
      estimatedTimeRemaining: 10,
      bytesDownloaded: 50_000_000,
      totalBytes: 100_000_000
    )
    XCTAssertEqual(
      fast.speedDescription,
      "12.5 MB/s",
      "Should format as MB/s"
    )

    // KB/s range
    let slow = ModelDownloadProgress(
      percentage: 0.1,
      bytesPerSecond: 500_000,
      estimatedTimeRemaining: 180,
      bytesDownloaded: 10_000_000,
      totalBytes: 100_000_000
    )
    XCTAssertEqual(
      slow.speedDescription,
      "500 KB/s",
      "Should format as KB/s"
    )
  }

  func testDownloadProgressETADescription() {
    // Seconds
    let shortETA = ModelDownloadProgress(
      percentage: 0.9,
      bytesPerSecond: 10_000_000,
      estimatedTimeRemaining: 30,
      bytesDownloaded: 90_000_000,
      totalBytes: 100_000_000
    )
    XCTAssertTrue(
      shortETA.etaDescription.contains("remaining"),
      "ETA should contain 'remaining'"
    )
    XCTAssertTrue(
      shortETA.etaDescription.contains("30s"),
      "Should show seconds for short ETA"
    )

    // Minutes
    let mediumETA = ModelDownloadProgress(
      percentage: 0.5,
      bytesPerSecond: 1_000_000,
      estimatedTimeRemaining: 150,
      bytesDownloaded: 50_000_000,
      totalBytes: 100_000_000
    )
    XCTAssertTrue(
      mediumETA.etaDescription.contains("m"),
      "Should show minutes for medium ETA"
    )

    // Nil ETA
    let unknownETA = ModelDownloadProgress(
      percentage: 0.01,
      bytesPerSecond: 0,
      estimatedTimeRemaining: nil,
      bytesDownloaded: 1_000_000,
      totalBytes: 100_000_000
    )
    XCTAssertEqual(
      unknownETA.etaDescription,
      "Calculating...",
      "Should show 'Calculating...' for nil ETA"
    )
  }
}

// MARK: - Disk Space Check Tests (B4)

final class DiskSpaceCheckTests: XCTestCase {

  func testDiskSpaceCheckBlocksDownload() {
    // Arrange — the diskSpaceInsufficient error
    // should contain required and available info
    let error = ModelManagerError.diskSpaceInsufficient(
      required: 2_900_000_000,
      available: 500_000_000
    )

    // Assert
    let description = error.errorDescription ?? ""
    XCTAssertTrue(
      description.contains("Insufficient"),
      "Error should mention insufficient space"
    )
    XCTAssertTrue(
      description.contains("Required"),
      "Error should mention required space"
    )
    XCTAssertTrue(
      description.contains("Available"),
      "Error should mention available space"
    )
  }

  func testCannotDeleteActiveModelError() {
    let error = ModelManagerError.cannotDeleteActiveModel
    let description = error.errorDescription ?? ""
    XCTAssertTrue(
      description.contains("Cannot delete"),
      "Error should explain that active model "
        + "cannot be deleted"
    )
  }
}

// MARK: - Model Management Tests (B5)

@MainActor
final class ModelManagementTests: XCTestCase {

  func testDeleteModelRemovesFile() async throws {
    // Arrange — create temporary model files
    let manager = ModelManager()

    // Use a model that is unlikely to be active
    // First, set active to base so we can delete small
    let activeModel = WhisperModelSize.base
    let deleteModel = WhisperModelSize.small
    let activePath = manager.modelPath(for: activeModel)
    let deletePath = manager.modelPath(for: deleteModel)

    // Ensure directory exists
    try FileManager.default.createDirectory(
      at: deletePath.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    // Create fake model files
    FileManager.default.createFile(
      atPath: activePath.path,
      contents: Data(repeating: 0, count: 100)
    )
    FileManager.default.createFile(
      atPath: deletePath.path,
      contents: Data(repeating: 0, count: 100)
    )

    // Set active model to base
    try manager.setActiveModel(activeModel)

    XCTAssertTrue(
      manager.isModelDownloaded(deleteModel),
      "Model should exist before deletion"
    )

    // Act — delete the non-active model
    try manager.deleteModel(deleteModel)

    // Assert
    XCTAssertFalse(
      manager.isModelDownloaded(deleteModel),
      "Model should be removed after deletion"
    )

    // Cleanup
    try? FileManager.default.removeItem(at: activePath)
  }

  func testDeleteActiveModelThrows() async throws {
    // Arrange — create and set as active
    let manager = ModelManager()
    let testModel = WhisperModelSize.tiny
    let modelPath = manager.modelPath(for: testModel)

    try FileManager.default.createDirectory(
      at: modelPath.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    FileManager.default.createFile(
      atPath: modelPath.path,
      contents: Data(repeating: 0, count: 100)
    )
    try manager.setActiveModel(testModel)

    // Act & Assert
    XCTAssertThrowsError(
      try manager.deleteModel(testModel)
    ) { error in
      guard let mmError = error
        as? ModelManagerError
      else {
        XCTFail("Should throw ModelManagerError")
        return
      }
      if case .cannotDeleteActiveModel = mmError {
        // Expected
      } else {
        XCTFail(
          "Should throw cannotDeleteActiveModel, "
            + "got: \(mmError)"
        )
      }
    }

    // Cleanup
    try? FileManager.default.removeItem(at: modelPath)
  }

  func testDownloadedModelsListIsAccurate() {
    let manager = ModelManager()
    let downloaded = manager.downloadedModels()

    // Each reported model should actually exist on disk
    for model in downloaded {
      XCTAssertTrue(
        manager.isModelDownloaded(model),
        "Reported model \(model.rawValue) should exist"
      )
    }
  }

  func testDownloadedModelsSummaryFormat() {
    let manager = ModelManager()
    let summary = manager.downloadedModelsSummary()

    // Summary should be non-empty
    XCTAssertFalse(
      summary.isEmpty,
      "Summary should not be empty"
    )
  }
}

// MARK: - Latency Estimation Tests (B7)

final class LatencyEstimationTests: XCTestCase {

  func testLatencyEstimationAppleSilicon() {
    // Apple Silicon latencies should be reasonable
    let tinyLatency =
      WhisperModelSize.tiny.estimatedLatencyAppleSilicon
    let largeLatency =
      WhisperModelSize.largeV3.estimatedLatencyAppleSilicon

    XCTAssertGreaterThan(
      tinyLatency,
      0,
      "Tiny latency should be positive"
    )
    XCTAssertLessThan(
      tinyLatency,
      largeLatency,
      "Tiny should be faster than Large"
    )
    XCTAssertLessThan(
      tinyLatency,
      1.0,
      "Tiny on Apple Silicon should be < 1s"
    )
  }

  func testLatencyEstimationIntel() {
    let tinyLatency =
      WhisperModelSize.tiny.estimatedLatencyIntel
    let largeLatency =
      WhisperModelSize.largeV3.estimatedLatencyIntel

    XCTAssertGreaterThan(
      tinyLatency,
      0,
      "Tiny Intel latency should be positive"
    )
    XCTAssertLessThan(
      tinyLatency,
      largeLatency,
      "Tiny should be faster than Large on Intel"
    )
    // Intel is always slower than Apple Silicon
    XCTAssertGreaterThan(
      tinyLatency,
      WhisperModelSize.tiny.estimatedLatencyAppleSilicon,
      "Intel should be slower than Apple Silicon"
    )
  }

  func testEstimatedLatencyReturnsDeviceSpecific() {
    let latency = WhisperModelSize.base.estimatedLatency()
    XCTAssertGreaterThan(
      latency,
      0,
      "Latency should be positive"
    )

    // Should match either Apple Silicon or Intel value
    let asSilicon =
      WhisperModelSize.base.estimatedLatencyAppleSilicon
    let asIntel =
      WhisperModelSize.base.estimatedLatencyIntel
    XCTAssertTrue(
      latency == asSilicon || latency == asIntel,
      "Should return Apple Silicon or Intel latency"
    )
  }

  func testLatencyDescriptionContainsEstimate() {
    for model in WhisperModelSize.allCases {
      let desc = model.latencyDescription
      XCTAssertTrue(
        desc.contains("Est. latency"),
        "Description should contain 'Est. latency' "
          + "for \(model.rawValue)"
      )
    }
  }

  func testLatencyIncreaseWithModelSize() {
    let models: [WhisperModelSize] = [
      .tiny, .base, .small, .medium, .largeV3,
    ]

    for i in 1..<models.count {
      XCTAssertGreaterThan(
        models[i].estimatedLatencyAppleSilicon,
        models[i - 1].estimatedLatencyAppleSilicon,
        "\(models[i].rawValue) should be slower than "
          + "\(models[i - 1].rawValue) on Apple Silicon"
      )
      XCTAssertGreaterThan(
        models[i].estimatedLatencyIntel,
        models[i - 1].estimatedLatencyIntel,
        "\(models[i].rawValue) should be slower than "
          + "\(models[i - 1].rawValue) on Intel"
      )
    }
  }
}

// MARK: - Speed & Accuracy Rating Tests (B1)

final class ModelRatingTests: XCTestCase {

  func testSpeedRatingValues() {
    // Tiny should be fastest (5), Large slowest (1)
    XCTAssertEqual(
      WhisperModelSize.tiny.speedRatingValue, 5
    )
    XCTAssertEqual(
      WhisperModelSize.base.speedRatingValue, 4
    )
    XCTAssertEqual(
      WhisperModelSize.small.speedRatingValue, 3
    )
    XCTAssertEqual(
      WhisperModelSize.medium.speedRatingValue, 2
    )
    XCTAssertEqual(
      WhisperModelSize.largeV3.speedRatingValue, 1
    )
  }

  func testAccuracyRatingValues() {
    // Tiny should be least accurate (1), Large best (5)
    XCTAssertEqual(
      WhisperModelSize.tiny.accuracyRatingValue, 1
    )
    XCTAssertEqual(
      WhisperModelSize.base.accuracyRatingValue, 2
    )
    XCTAssertEqual(
      WhisperModelSize.small.accuracyRatingValue, 3
    )
    XCTAssertEqual(
      WhisperModelSize.medium.accuracyRatingValue, 4
    )
    XCTAssertEqual(
      WhisperModelSize.largeV3.accuracyRatingValue, 5
    )
  }

  func testSpeedRatingContainsLightningBolts() {
    for model in WhisperModelSize.allCases {
      let rating = model.speedRating
      XCTAssertTrue(
        rating.contains("⚡"),
        "Speed rating should contain ⚡ for "
          + "\(model.rawValue)"
      )
    }
  }

  func testAccuracyRatingContainsStars() {
    for model in WhisperModelSize.allCases {
      let rating = model.accuracyRating
      XCTAssertTrue(
        rating.contains("⭐"),
        "Accuracy rating should contain ⭐ for "
          + "\(model.rawValue)"
      )
    }
  }

  func testDiskSizeDescription() {
    XCTAssertEqual(
      WhisperModelSize.tiny.diskSizeDescription,
      "39 MB"
    )
    XCTAssertEqual(
      WhisperModelSize.medium.diskSizeDescription,
      "1.5 GB"
    )
    XCTAssertEqual(
      WhisperModelSize.largeV3.diskSizeDescription,
      "2.9 GB"
    )
  }
}

// MARK: - Onboarding Model Selection Tests (B6)

final class OnboardingModelSelectionTests: XCTestCase {

  func testOnboardingSelectsRecommendedModel() {
    // The default model for onboarding should match
    // the device recommendation
    let recommended = DeviceProfiler.recommendedModel()

    // Verify the recommendation is valid
    XCTAssertTrue(
      WhisperModelSize.allCases.contains(recommended),
      "Recommended model should be valid"
    )

    // Verify it makes sense for the device
    let ramGB = DeviceProfiler.totalRAMGB
    if ramGB < 8 {
      XCTAssertEqual(
        recommended,
        .base,
        "Low RAM should default to Base"
      )
    }
  }

  func testDeviceProfilerStaticProperties() {
    XCTAssertGreaterThan(
      DeviceProfiler.totalRAM,
      0,
      "Should detect RAM"
    )
    XCTAssertGreaterThan(
      DeviceProfiler.cpuCoreCount,
      0,
      "Should detect CPU cores"
    )
    XCTAssertGreaterThan(
      DeviceProfiler.totalRAMGB,
      0,
      "RAM in GB should be positive"
    )
  }
}
