@preconcurrency import AVFoundation

// MARK: - Protocols and Types (cross-platform)

protocol AudioCaptureDelegate: AnyObject {
    func didStartCapture()
    func didStopCapture()
    func didReceiveAudioBuffer(_ buffer: AVAudioPCMBuffer)
    func didFailWithError(_ error: Error)
}

enum AudioCaptureError: LocalizedError {
    case microphonePermissionDenied
    case deviceNotFound
    case engineStartFailed
    case noAudioCaptured

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission denied. Please enable in System Settings."
        case .deviceNotFound:
            return "Audio input device not found."
        case .engineStartFailed:
            return "Failed to start audio engine."
        case .noAudioCaptured:
            return "No audio was captured."
        }
    }
}

#if os(macOS)
import AppKit

/// Manages microphone audio capture using AVAudioEngine.
actor AudioCaptureManager {

    // MARK: - Properties

    nonisolated(unsafe) weak var delegate: AudioCaptureDelegate?

    private var engine: AVAudioEngine
    private var audioBuffer: AudioSampleBuffer
    private var selectedInputDeviceUID: String?

    private(set) var isCapturing = false
    private(set) var audioLevel: Float = 0.0

    /// Smoothed audio level with attack/decay for VU meter (A3)
    private(set) var smoothedAudioLevel: Float = 0.0

    /// Attack coefficient — how fast the meter rises
    private let attackCoefficient: Float = 0.3

    /// Decay coefficient — how fast the meter falls
    private let decayCoefficient: Float = 0.05

    private let delegateQueue = DispatchQueue(
        label: "com.soundvibe.audio.delegate",
        attributes: .concurrent
    )

    // MARK: - Initialization

    init() {
        self.engine = AVAudioEngine()
        self.audioBuffer = AudioSampleBuffer()
    }

    // MARK: - Public Methods

    /// Requests microphone permission and begins audio capture.
    func startCapture() async throws {
        try await requestMicrophonePermissionIfNeeded()

        guard !isCapturing else { return }

        try configureAudioEngine()

        isCapturing = true
        delegateQueue.async { [weak self] in
            self?.delegate?.didStartCapture()
        }
    }

    /// Stops audio capture and returns collected audio as 16kHz mono PCM.
    func stopCapture() async -> Data {
        guard isCapturing else { return Data() }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        isCapturing = false

        let audioData = await audioBuffer.consolidate(sampleRate: 16000)
        await audioBuffer.reset()

        delegateQueue.async { [weak self] in
            self?.delegate?.didStopCapture()
        }

        return convertFloatArrayToData(audioData)
    }

    // MARK: - Private Methods

    private func requestMicrophonePermissionIfNeeded() async throws {
        let currentPermission = AVCaptureDevice.authorizationStatus(for: .audio)

        switch currentPermission {
        case .denied, .restricted:
            throw AudioCaptureError.microphonePermissionDenied
        case .authorized:
            return
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            if !granted {
                throw AudioCaptureError.microphonePermissionDenied
            }
        @unknown default:
            throw AudioCaptureError.microphonePermissionDenied
        }
    }

    private func configureAudioEngine() throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputFormat
        ) { [weak self] buffer, _ in
            Task {
                await self?.didReceiveAudioBuffer(buffer)
            }
        }

        engine.prepare()

        do {
            try engine.start()
        } catch {
            throw AudioCaptureError.engineStartFailed
        }
    }

    private func didReceiveAudioBuffer(
        _ buffer: AVAudioPCMBuffer
    ) async {
        await audioBuffer.append(buffer)

        let level = calculateRMSLevel(buffer)
        audioLevel = level

        // A3: Apply smoothing with attack/decay
        if level > smoothedAudioLevel {
            smoothedAudioLevel += attackCoefficient
                * (level - smoothedAudioLevel)
        } else {
            smoothedAudioLevel += decayCoefficient
                * (level - smoothedAudioLevel)
        }

        delegateQueue.async { [weak self] in
            self?.delegate?.didReceiveAudioBuffer(buffer)
        }
    }

    private func calculateRMSLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard buffer.format.channelCount > 0, let channels = buffer.floatChannelData else {
            return 0.0
        }

        let channelData = channels[0]
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0.0 }

        var sum: Float = 0
        for i in 0..<frameLength {
            let value = channelData[i]
            sum += value * value
        }

        let meanSquare = sum / Float(frameLength)
        let rms = sqrt(meanSquare)

        let normalized = (20 * log10(rms + 0.001) + 60) / 60
        return max(0, min(1, normalized))
    }

    private func convertFloatArrayToData(_ floatArray: [Float]) -> Data {
        var int16Array: [Int16] = []
        int16Array.reserveCapacity(floatArray.count)

        for float in floatArray {
            let clipped = max(-1.0, min(1.0, float))
            let int16 = Int16(clipped * 32767)
            int16Array.append(int16)
        }

        return int16Array.withUnsafeBytes { Data($0) }
    }
}

#endif
