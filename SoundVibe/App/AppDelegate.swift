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

    private func loadWhisperModelAsync(
        whisper: WhisperEngine,
        variant: String,
        menuBar: MenuBarManager
    ) {
        menuBar.updateStatusText("Loading Whisper model...")
        NSLog("[SoundVibe] Starting Whisper model load: \(variant)")
        Task {
            do {
                try await whisper.loadModel(variant: variant)
                menuBar.updateStatusText("Ready")
                NSLog("[SoundVibe] Whisper model loaded: \(variant)")
            } catch {
                NSLog("[SoundVibe] Whisper load FAILED: \(error)")
                menuBar.updateStatusText(
                    "⚠️ Model failed to load"
                )
            }
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
