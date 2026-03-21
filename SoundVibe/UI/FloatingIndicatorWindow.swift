#if os(macOS)

import AppKit
import SwiftUI

// MARK: - Indicator State Model

/// Observable model that drives the floating indicator UI.
///
/// Holds the current indicator state (listening, processing, etc.)
/// and the audio waveform data. SwiftUI views observe this model
/// via `@ObservedObject` to re-render when values change.
class IndicatorStateModel: ObservableObject {
    enum IndicatorState {
        case warmingUp
        case listening
        case finishing
        case processing
        case success
        case error
        case silenceWarning
    }

    /// Number of bars in the waveform visualization.
    /// Each bar corresponds to one RMS audio level sample.
    static let barCount = 20

    @Published var state: IndicatorState = .listening
    @Published var errorMessage: String = ""

    /// Phase accumulator for the processing spinner animation.
    @Published var waveformPhase: Double = 0

    /// Rolling buffer of recent audio RMS levels (0.0–1.0).
    ///
    /// This acts as a fixed-size circular history:
    /// - Index 0 is the oldest sample
    /// - Last index is the most recent sample
    ///
    /// The `DictationOrchestrator` polls `AudioCaptureManager.audioLevel`
    /// at ~20Hz and calls `pushAudioLevel()` to feed new samples.
    /// The `AnimatedWaveform` view reads this array to set bar heights.
    @Published var audioLevels: [Float] = Array(
        repeating: 0, count: IndicatorStateModel.barCount
    )

    /// Appends a new audio level to the rolling buffer.
    ///
    /// Shifts all existing samples one position to the left
    /// (dropping the oldest) and inserts the new sample at the end.
    /// This creates a scrolling waveform effect: new audio appears
    /// on the right and scrolls left over time.
    ///
    /// - Parameter level: Normalized RMS level from 0.0 (silence)
    ///   to 1.0 (maximum volume).
    func pushAudioLevel(_ level: Float) {
        audioLevels.removeFirst()
        audioLevels.append(level)
    }
}

// MARK: - Floating Indicator Window

/// A floating, non-activating overlay window that displays recording and processing status
class FloatingIndicatorWindow: NSPanel {
    let stateModel = IndicatorStateModel()
    private var hideTimer: Timer?
    private var animationTimer: Timer?

    init() {
        let contentView = FloatingIndicatorContentView(stateModel: stateModel)
        let hostingView = NSHostingView(rootView: contentView)

        let rect = NSRect(x: 0, y: 0, width: 200, height: 100)
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        self.contentView = hostingView
        self.isFloatingPanel = true
        self.level = .floating
        self.hasShadow = true
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        positionNearCursor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    func showWarmingUp() {
        DispatchQueue.main.async {
            self.stateModel.state = .warmingUp
            self.stateModel.audioLevels = Array(
                repeating: 0,
                count: IndicatorStateModel.barCount
            )
            self.positionNearCursor()
            self.orderFrontRegardless()
            self.scheduleHideTimer(after: 30)
        }
    }

    func showListening() {
        DispatchQueue.main.async {
            self.stateModel.state = .listening
            // Reset audio levels for a fresh waveform
            self.stateModel.audioLevels = Array(
                repeating: 0,
                count: IndicatorStateModel.barCount
            )
            self.positionNearCursor()
            self.orderFrontRegardless()
            self.scheduleHideTimer(after: 30)
        }
    }

    func showFinishing() {
        DispatchQueue.main.async {
            self.stateModel.state = .finishing
            self.positionNearCursor()
            self.orderFrontRegardless()
            self.scheduleHideTimer(after: 5)
        }
    }

    func showProcessing() {
        DispatchQueue.main.async {
            self.stateModel.state = .processing
            self.positionNearCursor()
            self.orderFrontRegardless()
            self.startProcessingAnimation()
            self.scheduleHideTimer(after: 10)
        }
    }

    func showSuccess() {
        DispatchQueue.main.async {
            self.stateModel.state = .success
            self.positionNearCursor()
            self.orderFrontRegardless()
            self.scheduleHideTimer(after: 1)
        }
    }

    func showSilenceWarning() {
        DispatchQueue.main.async {
            self.stateModel.state = .silenceWarning
            self.positionNearCursor()
            self.orderFrontRegardless()
            self.scheduleHideTimer(after: 10)
        }
    }

    func showError(message: String = "An error occurred") {
        DispatchQueue.main.async {
            self.stateModel.errorMessage = message
            self.stateModel.state = .error
            self.positionNearCursor()
            self.orderFrontRegardless()
            self.scheduleHideTimer(after: 3)
        }
    }

    func hideIndicator() {
        DispatchQueue.main.async {
            self.orderOut(nil)
            self.hideTimer?.invalidate()
            self.hideTimer = nil
            self.stopAnimations()
        }
    }

    // MARK: - Private Methods

    private func positionNearCursor() {
        let cursor = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        var x = cursor.x + 20
        var y = cursor.y - 50

        x = min(max(x, screenFrame.minX), screenFrame.maxX - self.frame.width)
        y = min(max(y, screenFrame.minY), screenFrame.maxY - self.frame.height)

        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func startWaveformAnimation() {
        stopAnimations()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.stateModel.waveformPhase += 0.1
            if self.stateModel.waveformPhase > 2 * Double.pi {
                self.stateModel.waveformPhase = 0
            }
        }
    }

    private func startProcessingAnimation() {
        stopAnimations()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.stateModel.waveformPhase += 0.1
        }
    }

    private func stopAnimations() {
        animationTimer?.invalidate()
        animationTimer = nil
        stateModel.waveformPhase = 0
    }

    private func scheduleHideTimer(after seconds: TimeInterval) {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.hideIndicator()
        }
    }
}

// MARK: - Content View

struct FloatingIndicatorContentView: View {
    @ObservedObject var stateModel: IndicatorStateModel
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        if !settings.showFloatingIndicator {
            EmptyView()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(radius: 8)

                VStack(spacing: 16) {
                    switch stateModel.state {
                    case .warmingUp:
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.0)

                            Text("Starting...")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }

                    case .listening:
                        VStack(spacing: 12) {
                            AnimatedWaveform(
                                audioLevels: stateModel.audioLevels
                            )
                            .frame(height: 40)
                            .animation(
                                .easeOut(duration: 0.05),
                                value: stateModel.audioLevels
                            )

                            Text("Listening...")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }

                    case .finishing:
                        VStack(spacing: 12) {
                            AnimatedWaveform(
                                audioLevels: stateModel.audioLevels
                            )
                            .frame(height: 40)
                            .opacity(0.6)

                            Text("Finishing...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }

                    case .processing:
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)

                            Text("Processing...")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }

                    case .success:
                        VStack(spacing: 12) {
                            Image(
                                systemName: "checkmark.circle.fill"
                            )
                            .font(.system(size: 40))
                            .foregroundColor(.green)

                            Text("Inserted!")
                                .font(.headline)
                                .foregroundColor(.green)
                        }

                    case .silenceWarning:
                        VStack(spacing: 8) {
                            Image(
                                systemName: "mic.slash"
                            )
                            .font(.system(size: 32))
                            .foregroundColor(.orange)

                            Text(
                                "⚠️ No audio detected — check mic"
                            )
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                        }

                    case .error:
                        VStack(spacing: 8) {
                            Image(
                                systemName:
                                    "exclamationmark.circle.fill"
                            )
                            .font(.system(size: 32))
                            .foregroundColor(.red)

                            Text(stateModel.errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                    }
                }
                .padding(20)
            }
            .frame(
                width: (stateModel.state == .error
                    || stateModel.state == .silenceWarning)
                    ? 250 : 200,
                height: 120
            )
            .background(Color.clear)
        }
    }
}

// MARK: - Animated Waveform

/// Waveform view driven by real audio levels.
/// Each bar represents a recent RMS audio sample, creating a
/// scrolling waveform that responds to the user's voice.
///
/// A4: Enhanced with exponential curve and color gradient
/// (green when speaking, blue when quiet).
struct AnimatedWaveform: View {
    let audioLevels: [Float]

    private let maxBarHeight: CGFloat = 40
    private let minBarHeight: CGFloat = 3

    /// A3: Threshold levels for VU meter coloring
    private let yellowThreshold: Float = 0.5
    private let redThreshold: Float = 0.8

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<audioLevels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(
                        width: 3,
                        height: barHeight(for: index)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = CGFloat(audioLevels[index])
        // A4: Apply exponential curve for visual punch
        let curved = pow(level, 1.5) * 0.6 + level * 0.4
        return minBarHeight + curved * maxBarHeight
    }

    /// A3/A4: Color gradient — green when speaking, blue when
    /// quiet, yellow/red at high levels.
    private func barColor(for index: Int) -> Color {
        let level = audioLevels[index]
        if level >= redThreshold {
            return .red
        } else if level >= yellowThreshold {
            return .yellow
        } else if level > 0.1 {
            return .green
        } else {
            return .blue
        }
    }
}

// MARK: - Manager

/// Singleton manager for the floating indicator window
class FloatingIndicatorManager {
    static let shared = FloatingIndicatorManager()

    private let window: FloatingIndicatorWindow

    private init() {
        window = FloatingIndicatorWindow()
    }

    func showWarmingUp() {
        window.showWarmingUp()
    }

    func showListening() {
        window.showListening()
    }

    func showFinishing() {
        window.showFinishing()
    }

    func showProcessing() {
        window.showProcessing()
    }

    func showSuccess() {
        window.showSuccess()
    }

    func showError(message: String = "An error occurred") {
        window.showError(message: message)
    }

    func showSilenceWarning() {
        window.showSilenceWarning()
    }

    func hide() {
        window.hideIndicator()
    }

    /// Push a real-time audio level (0–1) to the waveform display.
    func updateAudioLevel(_ level: Float) {
        window.stateModel.pushAudioLevel(level)
    }
}

#endif
