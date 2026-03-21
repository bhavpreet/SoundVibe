import Foundation
import AppKit
import SwiftUI
import OSLog

/// Application delegate that handles initialization and lifecycle
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Private Properties

    private var dictationOrchestrator: DictationOrchestrator?
    private var hotkeyManager: HotkeyManager?
    private var audioCapture: AudioCaptureManager?
    private var menuBarManager: MenuBarManager?
    private var floatingIndicatorManager: FloatingIndicatorManager?
    private var whisperEngine: WhisperEngine?
    private var postProcessingPipeline: PostProcessingPipeline?
    private var textInsertionEngine: TextInsertionEngine?
    private var onboardingWindow: NSWindow?

    private let logger = Logger(
        subsystem: "com.soundvibe.app", category: "AppDelegate"
    )

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupApplication()
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleanupApplication()
    }

    // MARK: - Setup

    private func setupApplication() {
        logger.info("Initializing SoundVibe")

        do {
            let settingsManager = SettingsManager.shared

            // Check onboarding
            let done = UserDefaults.standard.bool(
                forKey: "SoundVibe_OnboardingCompleted"
            )
            if !done {
                showOnboarding()
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(onboardingDidComplete),
                    name: NSNotification.Name(
                        "SoundVibe_OnboardingCompleted"
                    ),
                    object: nil
                )
                return
            }

            // Initialize UI managers
            let menuBar = MenuBarManager.shared
            let indicator = FloatingIndicatorManager.shared

            // Initialize audio capture
            let audio = AudioCaptureManager()

            // Ensure models directory
            try WhisperModelSize.ensureModelsDirectoryExists()

            // Initialize whisper engine (model loaded async below)
            let whisper = WhisperEngine()

            // Initialize text insertion
            let textInsertion = TextInsertionEngine()

            // Initialize post-processing pipeline with rule-based
            // processor. Real MLX LLM requires Xcode project build.
            let postProcessor = MLXPostProcessor()
            let pipeline = PostProcessingPipeline(postProcessor: postProcessor)

            // Initialize hotkey manager
            let hotkey = HotkeyManager(
                hotkey: settingsManager.hotkey,
                triggerMode: settingsManager.triggerMode
            )

            // Initialize orchestrator
            let orchestrator = DictationOrchestrator(
                audioCapture: audio,
                transcriptionEngine: whisper,
                postProcessingPipeline: pipeline,
                textInsertion: textInsertion,
                settingsManager: settingsManager,
                hotkeyManager: hotkey,
                menuBarManager: menuBar,
                floatingIndicatorManager: indicator
            )

            // Connect hotkey and start listening
            hotkey.delegate = orchestrator
            try hotkey.start()
            logger.info("Global hotkey listening started")

            // Store references
            self.dictationOrchestrator = orchestrator
            self.hotkeyManager = hotkey
            self.audioCapture = audio
            self.menuBarManager = menuBar
            self.floatingIndicatorManager = indicator
            self.whisperEngine = whisper
            self.postProcessingPipeline = pipeline
            self.textInsertionEngine = textInsertion

            // Load Whisper model async in background
            loadWhisperModelAsync(
                whisper: whisper,
                variant: settingsManager.selectedModelSize.rawValue,
                menuBar: menuBar
            )

            // Load post-processor if enabled
            if settingsManager.postProcessingEnabled {
                Task {
                    try? await postProcessor.loadModel()
                    NSLog("[SoundVibe] Post-processor loaded")
                }
            }

            logger.info("SoundVibe initialization completed")

        } catch let error as HotkeyError {
            logger.error("Hotkey error: \(error.localizedDescription)")
            showErrorAlert(
                title: "Hotkey Registration Failed",
                message: error.localizedDescription
                    + "\n\nPlease enable accessibility permissions."
            )
        } catch {
            logger.error("Init error: \(error.localizedDescription)")
            showErrorAlert(
                title: "Initialization Error",
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Async Model Loading

    /// Validate that a WhisperKit model folder contains all
    /// required files for successful loading
    private func validateWhisperKitModel(
      at folderPath: String
    ) -> Bool {
      return WhisperModelSize.requiredModelFiles
        .allSatisfy { file in
        let filePath = (folderPath as NSString)
          .appendingPathComponent(file)
        return FileManager.default.fileExists(atPath: filePath)
      }
    }

    private func loadWhisperModelAsync(
        whisper: WhisperEngine,
        variant: String,
        menuBar: MenuBarManager
    ) {
        // Check for a pre-downloaded model from onboarding
        let cachedFolder = UserDefaults.standard.string(
            forKey: "soundvibe.whisperModelFolder"
        )

        // MARK: - Debug Logging

        #if DEBUG
        NSLog("[SoundVibe] === Model Cache Check ===")
        NSLog(
          "[SoundVibe] Cached folder path: "
            + "\(cachedFolder ?? "nil")"
        )

        if let folder = cachedFolder {
          let exists = FileManager.default
            .fileExists(atPath: folder)
          NSLog("[SoundVibe] Folder exists: \(exists)")

          if exists {
            do {
              let contents = try FileManager.default
                .contentsOfDirectory(atPath: folder)
              NSLog(
                "[SoundVibe] Folder contents: \(contents)"
              )
              NSLog(
                "[SoundVibe] File count: \(contents.count)"
              )

              let hasConfig = contents.contains("config.json")
              let hasTokenizer = contents
                .contains("tokenizer.json")
              let hasModel = contents
                .contains(where: { $0.contains("model") })
              NSLog(
                "[SoundVibe] Has config.json: \(hasConfig)"
              )
              NSLog(
                "[SoundVibe] Has tokenizer.json: "
                  + "\(hasTokenizer)"
              )
              NSLog(
                "[SoundVibe] Has model file: \(hasModel)"
              )
            } catch {
              NSLog(
                "[SoundVibe] Failed to list folder: "
                  + "\(error)"
              )
            }
          }
        }
        NSLog("[SoundVibe] === End Cache Check ===")
        #endif

        if let folder = cachedFolder,
           FileManager.default.fileExists(atPath: folder),
           validateWhisperKitModel(at: folder) {
            menuBar.updateStatusText("Loading model...")
            NSLog(
              "[SoundVibe] Loading cached model from: "
                + "\(folder)"
            )
            Task {
                do {
                    try await whisper.loadModel(
                      fromFolder: folder
                    )
                    menuBar.updateStatusText("Ready")
                    NSLog(
                      "[SoundVibe] Model loaded from cache"
                    )
                } catch {
                    NSLog(
                      "[SoundVibe] Cache load failed: "
                        + "\(error.localizedDescription)"
                    )
                    NSLog(
                      "[SoundVibe] Retrying in 1 second..."
                    )

                    // Give WhisperKit time to finalize
                    try? await Task.sleep(for: .seconds(1))

                    do {
                        try await whisper.loadModel(
                          fromFolder: folder
                        )
                        NSLog(
                          "[SoundVibe] Retry successful"
                        )
                        menuBar.updateStatusText("Ready")
                    } catch {
                        NSLog(
                          "[SoundVibe] Retry failed, "
                            + "will re-download: \(error)"
                        )
                        await downloadModel(
                            whisper: whisper,
                            variant: variant,
                            menuBar: menuBar
                        )
                    }
                }
            }
        } else {
            Task {
                await downloadModel(
                    whisper: whisper,
                    variant: variant,
                    menuBar: menuBar
                )
            }
        }
    }

    private func downloadModel(
        whisper: WhisperEngine,
        variant: String,
        menuBar: MenuBarManager
    ) async {
        menuBar.updateStatusText("Downloading model...")
        NSLog("[SoundVibe] Downloading Whisper model: \(variant)")
        do {
            try await whisper.loadModel(variant: variant)
            // Cache the model folder path so subsequent launches
            // skip the download and load from disk directly.
            if let folder = whisper.currentModelPath {
                UserDefaults.standard.set(
                    folder,
                    forKey: "soundvibe.whisperModelFolder"
                )
                NSLog("[SoundVibe] Cached model path: \(folder)")
            }
            menuBar.updateStatusText("Ready")
            NSLog("[SoundVibe] Whisper model downloaded: \(variant)")
        } catch {
            NSLog("[SoundVibe] Whisper download FAILED: \(error)")
            menuBar.updateStatusText("⚠️ Model failed to load")
        }
    }

    // MARK: - Cleanup

    private func cleanupApplication() {
        logger.info("Cleaning up")
        hotkeyManager?.stop()

        if let audio = audioCapture {
            Task { _ = await audio.stopCapture() }
        }

        whisperEngine?.unloadModel()
        logger.info("Cleanup completed")
    }

    // MARK: - Onboarding

    @objc private func onboardingDidComplete() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("SoundVibe_OnboardingCompleted"),
            object: nil
        )
        onboardingWindow?.close()
        onboardingWindow = nil
        logger.info("Onboarding completed, initializing")
        setupApplication()
    }

    private func showOnboarding() {
        logger.info("Showing onboarding flow")

        let onboardingView = OnboardingView()
        let hostingView = NSHostingView(rootView: onboardingView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = "Welcome to SoundVibe"
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)

        self.onboardingWindow = window
    }

    // MARK: - Error Alert

    private func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
