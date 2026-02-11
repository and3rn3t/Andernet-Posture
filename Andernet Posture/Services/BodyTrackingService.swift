//
//  BodyTrackingService.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import Foundation
import ARKit
import RealityKit
import QuartzCore
import simd

/// Protocol for body tracking data providers. Enables mock injection for testing.
protocol BodyTrackingService: AnyObject {
    /// Whether AR body tracking is available on this device.
    static var isSupported: Bool { get }
    /// Callback invoked on each frame with tracked joint positions.
    var onBodyUpdate: (([JointName: SIMD3<Float>], TimeInterval) -> Void)? { get set }
    /// Callback for session errors.
    var onError: ((Error) -> Void)? { get set }
    /// Start tracking.
    func start(in arView: ARView)
    /// Stop tracking.
    func stop(in arView: ARView)
}

// Note: The legacy ARBodyTrackingService class has been removed.
// All AR body-tracking, skeleton overlay rendering, and frame-rate
// throttling are handled by BodyARView.Coordinator.
