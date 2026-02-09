//
//  SmoothnessAnalyzer.swift
//  Andernet Posture
//
//  Movement smoothness analysis using SPARC (Spectral Arc Length)
//  and Harmonic Ratio metrics from accelerometer data.
//
//  References:
//  - Balasubramanian S et al., J Neuroengineering Rehab, 2015 (SPARC)
//  - Menz HB et al., Gait & Posture, 2003 (Harmonic Ratio)
//  - Lowry KA et al., Gait & Posture, 2012 (gait smoothness interpretation)
//

import Foundation

// MARK: - Results

/// Movement smoothness metrics.
struct SmoothnessMetrics: Sendable {
    /// SPARC (Spectral Arc Length) — more negative = less smooth.
    /// Normal walking ≈ -1.5 to -2.5. Pathological > -3.0.
    let sparcScore: Double

    /// Harmonic Ratio — ratio of even to odd harmonics in acceleration.
    /// Higher = smoother. Normal > 2.0 for AP, > 1.5 for ML.
    let harmonicRatioAP: Double
    let harmonicRatioML: Double

    /// Jerk metric — derivative of acceleration magnitude. Lower = smoother.
    let normalizedJerk: Double
}

// MARK: - Protocol

protocol SmoothnessAnalyzer: AnyObject {
    /// Record an acceleration sample for smoothness analysis.
    func recordSample(
        timestamp: TimeInterval,
        accelerationAP: Double,   // anteroposterior (Z in body frame)
        accelerationML: Double,   // mediolateral (X in body frame)
        accelerationV: Double     // vertical (Y in body frame)
    )

    /// Compute smoothness metrics from recorded samples.
    func analyze() -> SmoothnessMetrics

    /// Reset state.
    func reset()
}

// MARK: - Default Implementation

final class DefaultSmoothnessAnalyzer: SmoothnessAnalyzer {

    private struct AccelSample {
        let timestamp: TimeInterval
        let ap: Double
        let ml: Double
        let v: Double
    }

    private var samples: [AccelSample] = []

    /// Minimum samples for FFT-based analysis (~3 seconds at 60Hz).
    private let minSamples = 128

    // MARK: - Record

    func recordSample(
        timestamp: TimeInterval,
        accelerationAP: Double,
        accelerationML: Double,
        accelerationV: Double
    ) {
        samples.append(AccelSample(
            timestamp: timestamp, ap: accelerationAP,
            ml: accelerationML, v: accelerationV
        ))
    }

    // MARK: - Analyze

    func analyze() -> SmoothnessMetrics {
        guard samples.count >= minSamples else {
            return SmoothnessMetrics(sparcScore: 0, harmonicRatioAP: 0,
                                    harmonicRatioML: 0, normalizedJerk: 0)
        }

        // Compute sampling frequency
        let totalTime = (samples.last?.timestamp ?? 0) - (samples.first?.timestamp ?? 0)
        guard totalTime > 0.5 else {
            return SmoothnessMetrics(sparcScore: 0, harmonicRatioAP: 0,
                                    harmonicRatioML: 0, normalizedJerk: 0)
        }
        let fs = Double(samples.count) / totalTime

        // Compute magnitude of acceleration
        let magnitudes = samples.map { sqrt($0.ap * $0.ap + $0.ml * $0.ml + $0.v * $0.v) }

        // SPARC
        let sparc = computeSPARC(signal: magnitudes, fs: fs)

        // Harmonic Ratio
        let hrAP = computeHarmonicRatio(signal: samples.map(\.ap), fs: fs)
        let hrML = computeHarmonicRatio(signal: samples.map(\.ml), fs: fs)

        // Normalized Jerk
        let jerk = computeNormalizedJerk(signal: magnitudes, fs: fs, duration: totalTime)

        return SmoothnessMetrics(
            sparcScore: sparc,
            harmonicRatioAP: hrAP,
            harmonicRatioML: hrML,
            normalizedJerk: jerk
        )
    }

    func reset() {
        samples.removeAll()
    }

    // MARK: - SPARC (Spectral Arc Length)

    /// Compute SPARC: the arc length of the frequency spectrum of the speed profile.
    /// More negative = less smooth.
    /// Ref: Balasubramanian S et al., 2015.
    private func computeSPARC(signal: [Double], fs: Double) -> Double {
        let n = signal.count
        guard n >= 4 else { return 0 }

        // Simple DFT magnitude spectrum (we avoid vDSP dependency for portability)
        let nfft = nextPowerOfTwo(n)
        let freqResolution = fs / Double(nfft)
        let maxFreq = min(20.0, fs / 2) // Limit to 20 Hz (gait relevant)
        let maxBin = Int(maxFreq / freqResolution)

        // Compute DFT magnitudes for relevant bins
        var spectrum: [Double] = []
        for k in 0...min(maxBin, nfft / 2) {
            var real = 0.0, imag = 0.0
            for i in 0..<n {
                let angle = -2.0 * Double.pi * Double(k) * Double(i) / Double(nfft)
                real += signal[i] * cos(angle)
                imag += signal[i] * sin(angle)
            }
            let mag = sqrt(real * real + imag * imag) / Double(n)
            spectrum.append(mag)
        }

        // Normalize spectrum
        guard let maxMag = spectrum.max(), maxMag > 1e-10 else { return 0 }
        let normalized = spectrum.map { $0 / maxMag }

        // Arc length of normalized spectrum
        var arcLength = 0.0
        let df = 1.0 / (maxFreq > 0 ? maxFreq : 1)
        for i in 1..<normalized.count {
            let dMag = normalized[i] - normalized[i-1]
            arcLength += sqrt(df * df + dMag * dMag)
        }

        return -arcLength // Negative: more negative = less smooth
    }

    // MARK: - Harmonic Ratio

    /// Compute harmonic ratio: ratio of even to odd harmonics.
    /// For AP/vertical: even/odd. For ML: odd/even (due to bilateral symmetry).
    /// Higher values indicate smoother, more symmetric gait.
    private func computeHarmonicRatio(signal: [Double], fs: Double) -> Double {
        let n = signal.count
        guard n >= 4 else { return 0 }

        // Compute first 20 harmonics via DFT
        let nHarmonics = 20

        // Estimate fundamental frequency (stride frequency ~0.8–1.2 Hz during walking)
        // Use stride frequency ≈ 1.0 Hz as starting estimate
        let strideFundamental = 1.0  // Hz
        let binSize = fs / Double(n)

        var harmonicMags: [Double] = Array(repeating: 0, count: nHarmonics)
        for h in 1...nHarmonics {
            let targetFreq = strideFundamental * Double(h)
            let k = Int(round(targetFreq / binSize))
            guard k < n / 2 else { break }

            var real = 0.0, imag = 0.0
            for i in 0..<n {
                let angle = -2.0 * Double.pi * Double(k) * Double(i) / Double(n)
                real += signal[i] * cos(angle)
                imag += signal[i] * sin(angle)
            }
            harmonicMags[h - 1] = sqrt(real * real + imag * imag) / Double(n)
        }

        // Even harmonics sum (h=2,4,6...) and odd harmonics sum (h=1,3,5...)
        var evenSum = 0.0, oddSum = 0.0
        for i in 0..<nHarmonics {
            if (i + 1) % 2 == 0 {
                evenSum += harmonicMags[i]
            } else {
                oddSum += harmonicMags[i]
            }
        }

        guard oddSum > 1e-10 else { return 0 }
        return evenSum / oddSum
    }

    // MARK: - Normalized Jerk

    /// Compute normalized jerk (dimensionless).
    /// Lower values indicate smoother movement.
    private func computeNormalizedJerk(signal: [Double], fs: Double, duration: Double) -> Double {
        guard signal.count >= 3, duration > 0, fs > 0 else { return 0 }

        let dt = 1.0 / fs
        var jerkSum = 0.0

        // Jerk = derivative of acceleration
        for i in 1..<(signal.count - 1) {
            let accelPrev = signal[i - 1]
            let accelNext = signal[i + 1]
            let jerk = (accelNext - accelPrev) / (2.0 * dt)
            jerkSum += jerk * jerk
        }

        // Normalize: -0.5 * T^5 / D^2 * integral(jerk^2)
        // Using simplified version: sqrt(jerk^2 / T) * T^(5/2)
        let peakAmp = (signal.max() ?? 1) - (signal.min() ?? 0)
        guard peakAmp > 1e-10 else { return 0 }

        let meanJerk2 = jerkSum / Double(signal.count - 2)
        return sqrt(meanJerk2) * pow(duration, 1.5) / peakAmp
    }

    // MARK: - Helpers

    private func nextPowerOfTwo(_ n: Int) -> Int {
        var p = 1
        while p < n { p *= 2 }
        return p
    }
}
