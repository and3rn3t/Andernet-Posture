//
//  BodyFrame.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import Foundation
import simd

/// A single frame of body tracking data captured during a session.
/// Stores all tracked joint world positions and computed posture metrics.
struct BodyFrame: Codable, Sendable {
    /// Time elapsed since session start, in seconds.
    let timestamp: TimeInterval
    /// World positions of all tracked joints at this frame.
    let joints: [String: [Float]]
    /// Trunk lean angle in degrees (0° = perfectly upright).
    let trunkLeanDeg: Double
    /// Lateral lean angle in degrees (0° = no lateral tilt).
    let lateralLeanDeg: Double
    /// Cadence at this point in steps per minute.
    let cadenceSPM: Double
    /// Rolling average stride length at this point.
    let avgStrideLengthM: Double

    /// Convenience initializer from SIMD3<Float> joint dictionary.
    init(
        timestamp: TimeInterval,
        joints: [JointName: SIMD3<Float>],
        trunkLeanDeg: Double,
        lateralLeanDeg: Double,
        cadenceSPM: Double,
        avgStrideLengthM: Double
    ) {
        self.timestamp = timestamp
        self.trunkLeanDeg = trunkLeanDeg
        self.lateralLeanDeg = lateralLeanDeg
        self.cadenceSPM = cadenceSPM
        self.avgStrideLengthM = avgStrideLengthM

        var encoded: [String: [Float]] = [:]
        for (name, pos) in joints {
            encoded[name.rawValue] = [pos.x, pos.y, pos.z]
        }
        self.joints = encoded
    }

    /// Decode joint positions back to SIMD3<Float>.
    func decodedJoints() -> [JointName: SIMD3<Float>] {
        var result: [JointName: SIMD3<Float>] = [:]
        for (key, arr) in joints {
            guard arr.count == 3, let name = JointName(rawValue: key) else { continue }
            result[name] = SIMD3<Float>(arr[0], arr[1], arr[2])
        }
        return result
    }
}
