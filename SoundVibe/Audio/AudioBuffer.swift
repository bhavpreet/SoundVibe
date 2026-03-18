import AVFoundation

/// Thread-safe accumulator for audio buffers collected during recording.
/// Manages buffer fragments and provides consolidated audio output.
actor AudioSampleBuffer {

    // MARK: - Properties

    private var buffers: [AVAudioPCMBuffer] = []

    private(set) var duration: TimeInterval = 0
    private(set) var currentLevel: Float = 0.0

    // MARK: - Public Methods

    /// Appends an audio buffer to the accumulator.
    func append(_ buffer: AVAudioPCMBuffer) {
        buffers.append(buffer)
        updateDuration()
        updateCurrentLevel(buffer)
    }

    /// Resets the buffer accumulator.
    func reset() {
        buffers.removeAll()
        duration = 0
        currentLevel = 0
    }

    /// Consolidates all buffered audio into a single Float array at the target sample rate.
    func consolidate(sampleRate targetRate: Double) -> [Float] {
        var result: [Float] = []

        guard !buffers.isEmpty else { return result }

        for buffer in buffers {
            guard let channels = buffer.floatChannelData else { continue }

            let frameLength = Int(buffer.frameLength)
            let sourceRate = buffer.format.sampleRate

            // If only one channel, use it directly
            if buffer.format.channelCount == 1 {
                let channelData = channels[0]
                let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

                if sourceRate == targetRate {
                    result.append(contentsOf: samples)
                } else {
                    let resampled = resample(samples, from: sourceRate, to: targetRate)
                    result.append(contentsOf: resampled)
                }
            } else {
                // Mix multiple channels to mono
                var monoSamples = [Float](repeating: 0, count: frameLength)
                for channelIndex in 0..<Int(buffer.format.channelCount) {
                    let channelData = channels[channelIndex]
                    for i in 0..<frameLength {
                        monoSamples[i] += channelData[i]
                    }
                }

                // Average across channels
                let channelCount = Float(buffer.format.channelCount)
                for i in 0..<frameLength {
                    monoSamples[i] /= channelCount
                }

                if sourceRate == targetRate {
                    result.append(contentsOf: monoSamples)
                } else {
                    let resampled = resample(monoSamples, from: sourceRate, to: targetRate)
                    result.append(contentsOf: resampled)
                }
            }
        }

        return result
    }

    // MARK: - Private Methods

    private func updateDuration() {
        duration = buffers.reduce(0) { total, buffer in
            let frameCount = Double(buffer.frameLength)
            let sampleRate = buffer.format.sampleRate
            let bufferDuration = frameCount / sampleRate
            return total + bufferDuration
        }
    }

    private func updateCurrentLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else {
            currentLevel = 0
            return
        }

        let channelData = channels[0]
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            let value = channelData[i]
            sum += value * value
        }

        let meanSquare = sum / Float(frameLength)
        let rms = sqrt(meanSquare)

        // Normalize to 0-1 range
        let normalized = (20 * log10(rms + 0.001) + 60) / 60
        currentLevel = max(0, min(1, normalized))
    }

    /// Simple linear interpolation resampling.
    /// For production, consider using more sophisticated resampling algorithms.
    private func resample(_ samples: [Float], from sourceRate: Double, to targetRate: Double) -> [Float] {
        guard sourceRate > 0, targetRate > 0, !samples.isEmpty else { return samples }

        let ratio = sourceRate / targetRate
        let targetCount = Int(ceil(Double(samples.count) / ratio))
        var result: [Float] = []
        result.reserveCapacity(targetCount)

        for i in 0..<targetCount {
            let sourceIndex = Double(i) * ratio
            let intIndex = Int(sourceIndex)
            let fracIndex = sourceIndex - Double(intIndex)

            if intIndex >= samples.count - 1 {
                result.append(samples[samples.count - 1])
            } else {
                let sample1 = samples[intIndex]
                let sample2 = samples[intIndex + 1]
                let interpolated = sample1 * (1 - Float(fracIndex)) + sample2 * Float(fracIndex)
                result.append(interpolated)
            }
        }

        return result
    }
}
