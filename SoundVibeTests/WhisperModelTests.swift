import XCTest
@testable import SoundVibe

final class WhisperModelTests: XCTestCase {

    // MARK: - Model Sizes Availability

    func testAllModelSizesAvailable() {
        let models = WhisperModelSize.allCases
        XCTAssertGreaterThan(models.count, 0, "Should have at least one model size available")
    }

    func testTinyModelExists() {
        let model = WhisperModelSize.tiny
        XCTAssertEqual(model.rawValue, "tiny", "Tiny model should exist")
    }

    func testBaseModelExists() {
        let model = WhisperModelSize.base
        XCTAssertEqual(model.rawValue, "base", "Base model should exist")
    }

    func testSmallModelExists() {
        let model = WhisperModelSize.small
        XCTAssertEqual(model.rawValue, "small", "Small model should exist")
    }

    func testMediumModelExists() {
        let model = WhisperModelSize.medium
        XCTAssertEqual(model.rawValue, "medium", "Medium model should exist")
    }

    func testLargeV3ModelExists() {
        let model = WhisperModelSize.largeV3
        XCTAssertEqual(model.rawValue, "large-v3", "Large V3 model should exist")
    }

    // MARK: - Display Names

    func testTinyDisplayName() {
        XCTAssertTrue(
            WhisperModelSize.tiny.displayName.contains("39MB"),
            "Tiny model display name should mention size"
        )
        XCTAssertTrue(
            WhisperModelSize.tiny.displayName.contains("Fastest"),
            "Tiny model display name should mention speed"
        )
    }

    func testBaseDisplayName() {
        XCTAssertTrue(
            WhisperModelSize.base.displayName.contains("140MB"),
            "Base model display name should mention size"
        )
    }

    func testSmallDisplayName() {
        XCTAssertTrue(
            WhisperModelSize.small.displayName.contains("466MB"),
            "Small model display name should mention size"
        )
    }

    func testMediumDisplayName() {
        XCTAssertTrue(
            WhisperModelSize.medium.displayName.contains("1.5GB"),
            "Medium model display name should mention size"
        )
    }

    func testLargeV3DisplayName() {
        XCTAssertTrue(
            WhisperModelSize.largeV3.displayName.contains("2.9GB"),
            "Large V3 model display name should mention size"
        )
        XCTAssertTrue(
            WhisperModelSize.largeV3.displayName.contains("Highest"),
            "Large V3 model display name should mention accuracy"
        )
    }

    // MARK: - File Names

    func testTinyFileName() {
        XCTAssertEqual(
            WhisperModelSize.tiny.fileName,
            "ggml-tiny.bin",
            "Tiny model file name should be ggml-tiny.bin"
        )
    }

    func testBaseFileName() {
        XCTAssertEqual(
            WhisperModelSize.base.fileName,
            "ggml-base.bin",
            "Base model file name should be ggml-base.bin"
        )
    }

    func testSmallFileName() {
        XCTAssertEqual(
            WhisperModelSize.small.fileName,
            "ggml-small.bin",
            "Small model file name should be ggml-small.bin"
        )
    }

    func testMediumFileName() {
        XCTAssertEqual(
            WhisperModelSize.medium.fileName,
            "ggml-medium.bin",
            "Medium model file name should be ggml-medium.bin"
        )
    }

    func testLargeV3FileName() {
        XCTAssertEqual(
            WhisperModelSize.largeV3.fileName,
            "ggml-large-v3.bin",
            "Large V3 model file name should be ggml-large-v3.bin"
        )
    }

    // MARK: - Download URLs

    func testDownloadURLValidURL() {
        for model in WhisperModelSize.allCases {
            let url = model.downloadURL
            XCTAssertNotNil(url, "Download URL should not be nil for \(model.rawValue)")
        }
    }

    func testDownloadURLBaseURL() {
        let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"
        for model in WhisperModelSize.allCases {
            let url = model.downloadURL
            XCTAssertTrue(
                url.absoluteString.contains(baseURL),
                "Download URL should contain base URL for \(model.rawValue)"
            )
        }
    }

    func testDownloadURLContainsFileName() {
        for model in WhisperModelSize.allCases {
            let url = model.downloadURL
            XCTAssertTrue(
                url.absoluteString.contains(model.fileName),
                "Download URL should contain file name for \(model.rawValue)"
            )
        }
    }

    func testTinyDownloadURL() {
        let url = WhisperModelSize.tiny.downloadURL
        XCTAssertTrue(
            url.absoluteString.contains("ggml-tiny.bin"),
            "Tiny download URL should contain ggml-tiny.bin"
        )
    }

    // MARK: - Disk Sizes

    func testDiskSizePositive() {
        for model in WhisperModelSize.allCases {
            XCTAssertGreaterThan(
                model.diskSize,
                0,
                "Disk size should be positive for \(model.rawValue)"
            )
        }
    }

    func testDiskSizeReasonable() {
        // Ensure sizes are in a reasonable range (between 30MB and 3GB)
        for model in WhisperModelSize.allCases {
            XCTAssertGreaterThan(
                model.diskSize,
                30_000_000,
                "Disk size should be at least 30MB for \(model.rawValue)"
            )
            XCTAssertLessThan(
                model.diskSize,
                3_000_000_000,
                "Disk size should be less than 3GB for \(model.rawValue)"
            )
        }
    }

    func testTinyDiskSize() {
        XCTAssertEqual(
            WhisperModelSize.tiny.diskSize,
            39_000_000,
            "Tiny model disk size should be 39MB"
        )
    }

    func testBaseDiskSize() {
        XCTAssertEqual(
            WhisperModelSize.base.diskSize,
            140_000_000,
            "Base model disk size should be 140MB"
        )
    }

    func testMediumDiskSize() {
        XCTAssertEqual(
            WhisperModelSize.medium.diskSize,
            1_500_000_000,
            "Medium model disk size should be 1.5GB"
        )
    }

    func testDiskSizeIncreasing() {
        let models = [
            WhisperModelSize.tiny,
            WhisperModelSize.base,
            WhisperModelSize.small,
            WhisperModelSize.medium,
            WhisperModelSize.largeV3
        ]

        for i in 1..<models.count {
            XCTAssertGreaterThan(
                models[i].diskSize,
                models[i - 1].diskSize,
                "Disk size should increase with model size"
            )
        }
    }

    // MARK: - Parameter Counts

    func testParameterCountPositive() {
        for model in WhisperModelSize.allCases {
            XCTAssertGreaterThan(
                model.parameterCount,
                0,
                "Parameter count should be positive for \(model.rawValue)"
            )
        }
    }

    func testParameterCountIncreasing() {
        let models = [
            WhisperModelSize.tiny,
            WhisperModelSize.base,
            WhisperModelSize.small,
            WhisperModelSize.medium,
            WhisperModelSize.largeV3
        ]

        for i in 1..<models.count {
            XCTAssertGreaterThan(
                models[i].parameterCount,
                models[i - 1].parameterCount,
                "Parameter count should increase with model size"
            )
        }
    }

    func testLargeV3ParameterCount() {
        XCTAssertEqual(
            WhisperModelSize.largeV3.parameterCount,
            1_550_000_000,
            "Large V3 should have 1.55 billion parameters"
        )
    }

    // MARK: - Relative Speed

    func testRelativeSpeedPositive() {
        for model in WhisperModelSize.allCases {
            XCTAssertGreaterThan(
                model.relativeSpeed,
                0,
                "Relative speed should be positive for \(model.rawValue)"
            )
        }
    }

    func testRelativeSpeedComparison() {
        // Tiny should be fastest (highest relative speed)
        XCTAssertGreaterThan(
            WhisperModelSize.tiny.relativeSpeed,
            WhisperModelSize.base.relativeSpeed,
            "Tiny should be faster than base"
        )

        // Base is the reference (1.0)
        XCTAssertEqual(
            WhisperModelSize.base.relativeSpeed,
            1.0,
            "Base model should have relative speed of 1.0"
        )

        // Larger models should be slower
        XCTAssertLessThan(
            WhisperModelSize.largeV3.relativeSpeed,
            WhisperModelSize.base.relativeSpeed,
            "Large V3 should be slower than base"
        )
    }

    func testTinySpeed() {
        XCTAssertEqual(
            WhisperModelSize.tiny.relativeSpeed,
            32.0,
            "Tiny model should be 32x faster than base"
        )
    }

    // MARK: - Word Error Rate

    func testWordErrorRateRange() {
        for model in WhisperModelSize.allCases {
            let wer = model.wordErrorRate
            XCTAssertGreaterThanOrEqual(
                wer,
                0.0,
                "Word error rate should be >= 0 for \(model.rawValue)"
            )
            XCTAssertLessThanOrEqual(
                wer,
                1.0,
                "Word error rate should be <= 1 for \(model.rawValue)"
            )
        }
    }

    func testWordErrorRateDecreasing() {
        // Better (larger) models should have lower WER
        XCTAssertGreaterThan(
            WhisperModelSize.tiny.wordErrorRate,
            WhisperModelSize.largeV3.wordErrorRate,
            "Tiny should have higher WER than Large V3"
        )
    }

    func testLargeV3WordErrorRate() {
        XCTAssertEqual(
            WhisperModelSize.largeV3.wordErrorRate,
            0.04,
            "Large V3 should have 4% word error rate"
        )
    }

    // MARK: - Models Directory

    func testModelsDirectoryPathIsValid() {
        let path = WhisperModelSize.modelsDirectory
        XCTAssertNotNil(path, "Models directory path should not be nil")
    }

    func testModelsDirectoryContainsSoundVibe() {
        let path = WhisperModelSize.modelsDirectory
        XCTAssertTrue(
            path.path.contains("SoundVibe"),
            "Models directory should contain 'SoundVibe' in path"
        )
    }

    func testModelsDirectoryContainsModels() {
        let path = WhisperModelSize.modelsDirectory
        XCTAssertTrue(
            path.path.contains("Models"),
            "Models directory should contain 'Models' in path"
        )
    }

    func testModelsDirectoryURL() {
        let path = WhisperModelSize.modelsDirectory
        XCTAssertTrue(
            path.pathComponents.contains("SoundVibe"),
            "Models directory should be under SoundVibe"
        )
    }

    // MARK: - Codable Tests

    func testModelSizeCodable() {
        let original = WhisperModelSize.medium

        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(original) else {
            XCTFail("Failed to encode WhisperModelSize")
            return
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(WhisperModelSize.self, from: encodedData) else {
            XCTFail("Failed to decode WhisperModelSize")
            return
        }

        XCTAssertEqual(decoded, original, "Decoded model size should match original")
    }

    func testAllModelSizesCodable() {
        for model in WhisperModelSize.allCases {
            let encoder = JSONEncoder()
            guard let encodedData = try? encoder.encode(model) else {
                XCTFail("Failed to encode \(model.rawValue)")
                return
            }

            let decoder = JSONDecoder()
            guard let decoded = try? decoder.decode(WhisperModelSize.self, from: encodedData) else {
                XCTFail("Failed to decode \(model.rawValue)")
                return
            }

            XCTAssertEqual(decoded, model, "Roundtrip encoding/decoding should preserve \(model.rawValue)")
        }
    }

    // MARK: - Raw Values

    func testRawValueMapping() {
        XCTAssertEqual(WhisperModelSize.tiny.rawValue, "tiny")
        XCTAssertEqual(WhisperModelSize.base.rawValue, "base")
        XCTAssertEqual(WhisperModelSize.small.rawValue, "small")
        XCTAssertEqual(WhisperModelSize.medium.rawValue, "medium")
        XCTAssertEqual(WhisperModelSize.largeV3.rawValue, "large-v3")
    }

    func testRawValueDecoding() {
        XCTAssertEqual(WhisperModelSize(rawValue: "tiny"), .tiny)
        XCTAssertEqual(WhisperModelSize(rawValue: "base"), .base)
        XCTAssertEqual(WhisperModelSize(rawValue: "small"), .small)
        XCTAssertEqual(WhisperModelSize(rawValue: "medium"), .medium)
        XCTAssertEqual(WhisperModelSize(rawValue: "large-v3"), .largeV3)
    }

    func testInvalidRawValue() {
        let invalid = WhisperModelSize(rawValue: "invalid-model")
        XCTAssertNil(invalid, "Invalid raw value should return nil")
    }

    // MARK: - Model Characteristics Relationships

    func testModelSpeedAccuracyTradeoff() {
        // Faster models should have worse accuracy (higher WER)
        let fast = WhisperModelSize.tiny
        let slow = WhisperModelSize.largeV3

        XCTAssertGreaterThan(fast.relativeSpeed, slow.relativeSpeed, "Tiny should be faster")
        XCTAssertGreaterThan(fast.wordErrorRate, slow.wordErrorRate, "Tiny should have worse accuracy")
    }

    func testModelSizeParameterRelationship() {
        // Larger models should have more parameters
        XCTAssertGreaterThan(
            WhisperModelSize.largeV3.parameterCount,
            WhisperModelSize.tiny.parameterCount,
            "Large V3 should have more parameters than Tiny"
        )
    }
}
