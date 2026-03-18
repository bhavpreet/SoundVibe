#if os(macOS)

import AppKit
import SwiftUI

// MARK: - Indicator State Model

/// Observable model for the floating indicator state
class IndicatorStateModel: ObservableObject {
    enum IndicatorState {
        case listening
        case processing
        case success
        case error
    }

    @Published var state: IndicatorState = .listening
    @Published var waveformPhase: Double = 0
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

    func showListening() {
        DispatchQueue.main.async {
            self.stateModel.state = .listening
            self.positionNearCursor()
            self.orderFrontRegardless()
            self.startWaveformAnimation()
            self.scheduleHideTimer(after: 30)
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

    func showError() {
        DispatchQueue.main.async {
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
                    case .listening:
                        VStack(spacing: 12) {
                            AnimatedWaveform(phase: stateModel.waveformPhase)
                                .frame(height: 40)

                            Text("Listening...")
                                .font(.headline)
                                .foregroundColor(.primary)
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
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)

                            Text("Inserted!")
                                .font(.headline)
                                .foregroundColor(.green)
                        }

                    case .error:
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red)

                            Text("Error")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(20)
            }
            .frame(width: 200, height: 120)
            .background(Color.clear)
        }
    }
}

// MARK: - Animated Waveform

struct AnimatedWaveform: View {
    let phase: Double
    let bars = 20

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<bars, id: \.self) { index in
                VStack {
                    Spacer()

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(
                            width: 3,
                            height: calculateBarHeight(for: index)
                        )

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func calculateBarHeight(for index: Int) -> Double {
        let position = Double(index) / Double(bars)
        let waveValue = sin(position * 2 * .pi + phase)
        let normalized = (waveValue + 1) / 2
        return normalized * 40 + 4
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

    func showListening() {
        window.showListening()
    }

    func showProcessing() {
        window.showProcessing()
    }

    func showSuccess() {
        window.showSuccess()
    }

    func showError() {
        window.showError()
    }

    func hide() {
        window.hideIndicator()
    }
}

#endif
