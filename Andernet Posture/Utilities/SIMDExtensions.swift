//
//  SIMDExtensions.swift
//  Andernet Posture
//
//  Helper extensions for SIMD math operations used in posture/gait analysis.
//

import simd

extension SIMD3 where Scalar == Float {
    /// Horizontal distance (XZ plane) between two points.
    func xzDistance(to other: SIMD3<Float>) -> Float {
        let dx = self.x - other.x
        let dz = self.z - other.z
        return sqrt(dx * dx + dz * dz)
    }

    /// Angle in degrees between this vector and the global up vector (0, 1, 0).
    var angleFromVerticalDeg: Float {
        let up = SIMD3<Float>(0, 1, 0)
        let norm = simd_length(self) > 0.001 ? simd_normalize(self) : up
        let cosTheta = simd_clamp(simd_dot(norm, up), -1, 1)
        return acos(cosTheta) * 180 / .pi
    }
}
