//
//  StepEvent.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import Foundation

/// A single foot-strike event detected during gait analysis.
struct StepEvent: Codable, Sendable {
    /// Represents which foot struck the ground.
    enum Foot: String, Codable, Sendable {
        case left
        case right
    }

    /// Time elapsed since session start, in seconds.
    let timestamp: TimeInterval
    /// Which foot made contact.
    let foot: Foot
    /// World-space XZ position of the foot at contact.
    let positionX: Float
    let positionZ: Float
    /// Stride length in meters (distance from previous same-foot strike). Nil for the first step.
    let strideLengthM: Double?
}
