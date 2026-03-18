// swift-tools-version: 5.12
import PackageDescription

let package = Package(
    name: "SoundVibe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SoundVibe", targets: ["SoundVibe"])
    ],
    dependencies: [
        // WhisperKit: CoreML-based Whisper speech-to-text
        .package(
            url: "https://github.com/argmaxinc/WhisperKit.git",
            from: "0.12.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "SoundVibe",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "SoundVibe",
            resources: [
                .copy("../Resources/Info.plist")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: "SoundVibeTests",
            dependencies: ["SoundVibe"],
            path: "SoundVibeTests"
        ),
    ]
)
