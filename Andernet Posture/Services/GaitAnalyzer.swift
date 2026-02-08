//
//  GaitAnalyzer.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import Foundation
import simd

/// Describes a detected foot strike during gait analysis.
struct FootStrike: Sendable {
    let foot: StepEvent.Foot
    let position: SIMD3<Float>
    let timestamp: TimeInterval
    let strideLengthM: Float?
}

/// Results from a single frame of gait analysis.
struct GaitMetrics: Sendable {
    let cadenceSPM: Double
    let avgStrideLengthM: Double
    let stepDetected: FootStrike?
    let symmetryRatio: Double? // 1.0 = perfectly symmetric
}

/// Protocol for gait analysis — step detection, cadence, stride length.
protocol GaitAnalyzer {
    /// Process a new frame of joint data.
    func processFrame(joints: [JointName: SIMD3<Float>], timestamp: TimeInterval) -> GaitMetrics

    /// Reset state between sessions.
    func reset()
}

// MARK: - Default Implementation

/// Extracts gait metrics using ankle Y-position local minima (foot strike detection).
/// Adapted from the existing inline logic in BodyARView.Coordinator.
final class DefaultGaitAnalyzer: GaitAnalyzer {

    // MARK: Sliding window for step detection

    /// Number of frames in the sliding window for local minimum detection.
    private let windowSize = 15

    /// Rolling buffers for ankle Y positions.
    private var leftAnkleYBuffer: [Float] = []
    private var rightAnkleYBuffer: [Float] = []

    /// Full position buffers (matching Y buffers) for stride length calculation.
    private var leftAnklePosBuf: [SIMD3<Float>] = []
    private var rightAnklePosBuf: [SIMD3<Float>] = []

    // MARK: Cadence tracking (rolling window)

    /// Timestamps of detected steps (both feet combined) within a rolling window.
    private var stepTimestamps: [TimeInterval] = []
    private let cadenceWindowSec: TimeInterval = 10.0

    // MARK: Stride length tracking

    private var lastLeftStrikePos: SIMD3<Float>?
    private var lastRightStrikePos: SIMD3<Float>?
    private var strideLengths: [Float] = []
    private let maxStrideSamples = 50

    // MARK: Symmetry tracking

    private var leftStrideLengths: [Float] = []
    private var rightStrideLengths: [Float] = []
    private let maxSymmetrySamples = 20

    // MARK: - Process Frame

    func processFrame(joints: [JointName: SIMD3<Float>], timestamp: TimeInterval) -> GaitMetrics {
        guard
            let leftAnkle = joints[.leftFoot],
            let rightAnkle = joints[.rightFoot]
        else {
            return GaitMetrics(cadenceSPM: 0, avgStrideLengthM: 0, stepDetected: nil, symmetryRatio: nil)
        }

        // Append Y values
        leftAnkleYBuffer.append(leftAnkle.y)
        rightAnkleYBuffer.append(rightAnkle.y)
        leftAnklePosBuf.append(leftAnkle)
        rightAnklePosBuf.append(rightAnkle)

        // Trim buffers to window size
        if leftAnkleYBuffer.count > windowSize {
            leftAnkleYBuffer.removeFirst()
            leftAnklePosBuf.removeFirst()
        }
        if rightAnkleYBuffer.count > windowSize {
            rightAnkleYBuffer.removeFirst()
            rightAnklePosBuf.removeFirst()
        }

        // Detect steps via local minimum in the middle of the sliding window
        var detectedStrike: FootStrike?

        if leftAnkleYBuffer.count == windowSize {
            if let strike = detectLocalMinStrike(
                yBuffer: leftAnkleYBuffer,
                posBuffer: leftAnklePosBuf,
                foot: .left,
                lastStrikePos: &lastLeftStrikePos,
                footStrideLengths: &leftStrideLengths,
                timestamp: timestamp
            ) {
                detectedStrike = strike
                stepTimestamps.append(timestamp)
            }
        }

        if rightAnkleYBuffer.count == windowSize {
            if let strike = detectLocalMinStrike(
                yBuffer: rightAnkleYBuffer,
                posBuffer: rightAnklePosBuf,
                foot: .right,
                lastStrikePos: &lastRightStrikePos,
                footStrideLengths: &rightStrideLengths,
                timestamp: timestamp
            ) {
                // Only one step per frame; prefer whichever was detected
                if detectedStrike == nil {
                    detectedStrike = strike
                }
                stepTimestamps.append(timestamp)
            }
        }

        // Record stride length
        if let strike = detectedStrike, let sl = strike.strideLengthM {
            strideLengths.append(sl)
            if strideLengths.count > maxStrideSamples {
                strideLengths.removeFirst()
            }
        }

        // Cadence — prune old timestamps
        stepTimestamps = stepTimestamps.filter { timestamp - $0 <= cadenceWindowSec }
        let cadence: Double
        if stepTimestamps.count >= 2, let first = stepTimestamps.first, let last = stepTimestamps.last {
            let elapsed = last - first
            cadence = elapsed > 0 ? Double(stepTimestamps.count - 1) / elapsed * 60.0 : 0
        } else {
            cadence = 0
        }

        // Average stride length
        let avgStride = strideLengths.isEmpty ? 0 : Double(strideLengths.reduce(0, +)) / Double(strideLengths.count)

        // Symmetry ratio
        let symmetry = computeSymmetry()

        return GaitMetrics(
            cadenceSPM: cadence,
            avgStrideLengthM: avgStride,
            stepDetected: detectedStrike,
            symmetryRatio: symmetry
        )
    }

    func reset() {
        leftAnkleYBuffer.removeAll()
        rightAnkleYBuffer.removeAll()
        leftAnklePosBuf.removeAll()
        rightAnklePosBuf.removeAll()
        stepTimestamps.removeAll()
        strideLengths.removeAll()
        leftStrideLengths.removeAll()
        rightStrideLengths.removeAll()
        lastLeftStrikePos = nil
        lastRightStrikePos = nil
    }

    // MARK: - Private Helpers

    private func detectLocalMinStrike(
        yBuffer: [Float],
        posBuffer: [SIMD3<Float>],
        foot: StepEvent.Foot,
        lastStrikePos: inout SIMD3<Float>?,
        footStrideLengths: inout [Float],
        timestamp: TimeInterval
    ) -> FootStrike? {
        let mid = windowSize / 2
        guard mid > 0, mid < yBuffer.count - 1 else { return nil }

        let midY = yBuffer[mid]

        // Check that the mid-point is a local minimum (lower than all neighbors in the window)
        var isMin = true
        for i in 0..<yBuffer.count where i != mid {
            if yBuffer[i] <= midY {
                isMin = false
                break
            }
        }
        guard isMin else { return nil }

        // Calculate stride length from last same-foot strike
        let pos = posBuffer[mid]
        var strideLen: Float?
        if let lastPos = lastStrikePos {
            let dx = pos.x - lastPos.x
            let dz = pos.z - lastPos.z
            let sl = sqrt(dx * dx + dz * dz)
            if sl > 0.1 && sl < 3.0 { // plausible stride range in meters
                strideLen = sl
                footStrideLengths.append(sl)
                if footStrideLengths.count > maxSymmetrySamples {
                    footStrideLengths.removeFirst()
                }
            }
        }
        lastStrikePos = pos

        return FootStrike(foot: foot, position: pos, timestamp: timestamp, strideLengthM: strideLen)
    }

    private func computeSymmetry() -> Double? {
        guard leftStrideLengths.count >= 3, rightStrideLengths.count >= 3 else { return nil }
        let avgLeft = Double(leftStrideLengths.reduce(0, +)) / Double(leftStrideLengths.count)
        let avgRight = Double(rightStrideLengths.reduce(0, +)) / Double(rightStrideLengths.count)
        guard avgLeft > 0, avgRight > 0 else { return nil }
        // Ratio: 1.0 = symmetric, <1.0 = shorter side / longer side
        return min(avgLeft, avgRight) / max(avgLeft, avgRight)
    }
}
