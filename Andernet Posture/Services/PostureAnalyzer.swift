//
//  PostureAnalyzer.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import Foundation
import simd

/// Results from a single frame of posture analysis.
struct PostureMetrics: Sendable {
    let trunkLeanDeg: Double
    let lateralLeanDeg: Double
    let headForwardDeg: Double
    let frameScore: Double
}

/// Protocol for posture analysis. Enables mock injection for testing.
protocol PostureAnalyzer {
    /// Analyze a set of joint positions and return posture metrics.
    func analyze(joints: [JointName: SIMD3<Float>]) -> PostureMetrics?

    /// Compute an overall session posture score from a series of trunk lean values.
    func computeSessionScore(trunkLeans: [Double], lateralLeans: [Double]) -> Double
}

// MARK: - Default Implementation

final class DefaultPostureAnalyzer: PostureAnalyzer {

    /// Threshold in degrees above which posture is considered "poor".
    private let maxTrunkLean: Double = 15.0
    private let maxLateralLean: Double = 10.0
    private let maxHeadForward: Double = 20.0

    func analyze(joints: [JointName: SIMD3<Float>]) -> PostureMetrics? {
        guard
            let hips = joints[.root],
            let neck = joints[.neck1]
        else { return nil }

        // --- Trunk lean (forward/backward) ---
        let torso = simd_normalize(neck - hips)
        let up = SIMD3<Float>(0, 1, 0)
        let cosTheta = simd_clamp(simd_dot(torso, up), -1, 1)
        let trunkLeanDeg = Double(acos(cosTheta) * 180 / .pi)

        // --- Lateral lean (side-to-side) ---
        // Project torso onto the XY plane (frontal plane)
        let lateralComponent = SIMD3<Float>(torso.x, torso.y, 0)
        let lateralNorm = simd_length(lateralComponent) > 0.001
            ? simd_normalize(lateralComponent)
            : up
        let cosLateral = simd_clamp(simd_dot(lateralNorm, up), -1, 1)
        let lateralLeanDeg = Double(acos(cosLateral) * 180 / .pi)

        // --- Head forward angle ---
        var headForwardDeg = 0.0
        if let head = joints[.head], let spine7 = joints[.spine7] {
            let headVec = simd_normalize(head - spine7)
            let cosHead = simd_clamp(simd_dot(headVec, up), -1, 1)
            headForwardDeg = Double(acos(cosHead) * 180 / .pi)
        }

        // --- Per-frame score (0-100) ---
        let trunkScore = max(0, 100 - (trunkLeanDeg / maxTrunkLean) * 100)
        let lateralScore = max(0, 100 - (lateralLeanDeg / maxLateralLean) * 100)
        let headScore = max(0, 100 - (headForwardDeg / maxHeadForward) * 100)

        // Weighted composite: trunk lean matters most
        let frameScore = trunkScore * 0.5 + lateralScore * 0.25 + headScore * 0.25

        return PostureMetrics(
            trunkLeanDeg: trunkLeanDeg,
            lateralLeanDeg: lateralLeanDeg,
            headForwardDeg: headForwardDeg,
            frameScore: min(100, max(0, frameScore))
        )
    }

    func computeSessionScore(trunkLeans: [Double], lateralLeans: [Double]) -> Double {
        guard !trunkLeans.isEmpty else { return 0 }

        let avgTrunk = trunkLeans.reduce(0, +) / Double(trunkLeans.count)
        let avgLateral = lateralLeans.isEmpty ? 0 : lateralLeans.reduce(0, +) / Double(lateralLeans.count)

        let trunkScore = max(0, 100 - (avgTrunk / maxTrunkLean) * 100)
        let lateralScore = max(0, 100 - (avgLateral / maxLateralLean) * 100)

        return min(100, max(0, trunkScore * 0.7 + lateralScore * 0.3))
    }
}
