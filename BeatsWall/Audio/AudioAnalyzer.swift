//
//  AudioAnalyzer.swift
//  BeatsWall
//

import Accelerate
import Foundation

/// Turns raw PCM into `AudioFeatures`: FFT, band energies, auto-gain, smoothing and beat detection.
/// Only ever called from the audio tap's serial queue.
nonisolated final class AudioAnalyzer: @unchecked Sendable {
    private static let fftSize = 1024
    private static let hopSize = 512
    private static let log2n = vDSP_Length(10)

    private let store: AudioFeaturesStore
    private let fftSetup: FFTSetup
    private let window: [Float]

    private var ring = [Float](repeating: 0, count: fftSize)
    private var writeIndex = 0
    private var samplesSinceAnalysis = 0
    private var frame = [Float](repeating: 0, count: fftSize)
    private var windowed = [Float](repeating: 0, count: fftSize)
    private var real = [Float](repeating: 0, count: fftSize / 2)
    private var imag = [Float](repeating: 0, count: fftSize / 2)
    private var magnitudes = [Float](repeating: 0, count: fftSize / 2)
    private var sampleRate: Double = 48_000

    private var features = AudioFeatures()
    // Auto-gain: slowly decaying peaks so quiet and loud tracks both fill the 0...1 range.
    private var levelPeak: Float = 0.01
    private var bassPeak: Float = 0.002
    private var midPeak: Float = 0.002
    private var treblePeak: Float = 0.002
    private var spectrumPeaks = [Float](repeating: 0.002, count: AudioFeatures.binCount)

    // Beat detection: compare instantaneous bass energy with its ~1 second average.
    private var bassHistory = [Float](repeating: 0, count: 43)
    private var bassHistoryIndex = 0
    private var lastBeatAt = -Double.infinity
    private var beatIntervals: [Double] = []

    init(store: AudioFeaturesStore) {
        self.store = store
        fftSetup = vDSP_create_fftsetup(Self.log2n, FFTRadix(kFFTRadix2))!
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: Self.fftSize, isHalfWindow: false)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func process(interleaved samples: UnsafePointer<Float>, frames: Int, channels: Int, sampleRate: Double) {
        self.sampleRate = sampleRate
        for index in 0..<frames {
            var sum: Float = 0
            for channel in 0..<channels {
                sum += samples[index * channels + channel]
            }
            ring[writeIndex] = sum / Float(channels)
            writeIndex = (writeIndex + 1) % Self.fftSize
            samplesSinceAnalysis += 1
            if samplesSinceAnalysis >= Self.hopSize {
                samplesSinceAnalysis = 0
                analyze()
            }
        }
    }

    private func analyze() {
        let n = Self.fftSize

        // Unroll the ring buffer, oldest sample first.
        let tail = n - writeIndex
        frame.withUnsafeMutableBufferPointer { destination in
            ring.withUnsafeBufferPointer { source in
                destination.baseAddress!.update(from: source.baseAddress! + writeIndex, count: tail)
                (destination.baseAddress! + tail).update(from: source.baseAddress!, count: writeIndex)
            }
        }

        let rms = vDSP.rootMeanSquare(frame)
        vDSP.multiply(frame, window, result: &windowed)

        real.withUnsafeMutableBufferPointer { realPointer in
            imag.withUnsafeMutableBufferPointer { imagPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                windowed.withUnsafeBufferPointer { input in
                    input.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(n / 2))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, Self.log2n, FFTDirection(FFT_FORWARD))
                split.imagp[0] = 0 // Nyquist is packed here; drop it.
                magnitudes.withUnsafeMutableBufferPointer { output in
                    vDSP_zvabs(&split, 1, output.baseAddress!, 1, vDSP_Length(n / 2))
                }
            }
        }
        vDSP.divide(magnitudes, Float(n), result: &magnitudes)

        let binHz = Float(sampleRate) / Float(n)
        let rawBass = bandEnergy(from: 20, to: 150, binHz: binHz)
        let rawMid = bandEnergy(from: 150, to: 2_000, binHz: binHz)
        let rawTreble = bandEnergy(from: 2_000, to: 12_000, binHz: binHz)

        features.level = smooth(features.level, normalize(rms, peak: &levelPeak, floor: 0.01))
        features.bass = smooth(features.bass, normalize(rawBass, peak: &bassPeak, floor: 0.002))
        features.mid = smooth(features.mid, normalize(rawMid, peak: &midPeak, floor: 0.001))
        features.treble = smooth(features.treble, normalize(rawTreble, peak: &treblePeak, floor: 0.0005))
        updateSpectrum(binHz: binHz)

        let beat = detectBeat(rawBass: rawBass)
        if beat { features.beatCount += 1 }

        store.publish(features, beat: beat, hasSignal: rms > 0.0001)
    }

    private func bandEnergy(from low: Float, to high: Float, binHz: Float) -> Float {
        let last = magnitudes.count - 1
        let start = min(last, max(1, Int(low / binHz)))
        let end = min(last, max(start, Int(high / binHz)))
        var sum: Float = 0
        for index in start...end { sum += magnitudes[index] }
        return sum / Float(end - start + 1)
    }

    private func updateSpectrum(binHz: Float) {
        let count = AudioFeatures.binCount
        let minHz: Float = 40, maxHz: Float = 16_000
        let globalPeak = spectrumPeaks.max() ?? 0.002
        for bin in 0..<count {
            let low = minHz * pow(maxHz / minHz, Float(bin) / Float(count))
            let high = minHz * pow(maxHz / minHz, Float(bin + 1) / Float(count))
            let start = min(magnitudes.count - 1, max(1, Int(low / binHz)))
            let end = min(magnitudes.count - 1, max(start, Int(high / binHz)))
            var value: Float = 0
            for index in start...end { value = max(value, magnitudes[index]) }
            // Per-bin auto-gain keeps the highs lively, but never amplifies a bin
            // past 20x below the loudest one, so noise stays quiet.
            let target = normalize(value, peak: &spectrumPeaks[bin], floor: max(0.0005, globalPeak * 0.05))
            features.spectrum[bin] = smooth(features.spectrum[bin], target, attack: 0.6, release: 0.18)
        }
    }

    private func detectBeat(rawBass: Float) -> Bool {
        let average = bassHistory.reduce(0, +) / Float(bassHistory.count)
        bassHistory[bassHistoryIndex] = rawBass
        bassHistoryIndex = (bassHistoryIndex + 1) % bassHistory.count

        let now = audioClock()
        guard rawBass > average * 1.4,
              rawBass > bassPeak * 0.25,
              now - lastBeatAt > 0.28 else { return false }

        let interval = now - lastBeatAt
        if interval < 1.5 {
            beatIntervals.append(interval)
            if beatIntervals.count > 12 { beatIntervals.removeFirst() }
            let median = beatIntervals.sorted()[beatIntervals.count / 2]
            features.bpm = Float(60 / median)
        }
        lastBeatAt = now
        return true
    }

    private func normalize(_ value: Float, peak: inout Float, floor: Float) -> Float {
        peak = max(value, peak * 0.9985, floor)
        // Slight curve restores contrast that auto-gain flattens.
        return pow(min(1, value / peak), 1.4)
    }

    private func smooth(_ current: Float, _ target: Float, attack: Float = 0.5, release: Float = 0.12) -> Float {
        current + (target - current) * (target > current ? attack : release)
    }
}
