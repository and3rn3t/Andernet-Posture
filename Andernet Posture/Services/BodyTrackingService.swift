//
//  BodyTrackingService.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import Foundation
import ARKit
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

// MARK: - ARKit Implementation

import RealityKit

final class ARBodyTrackingService: NSObject, BodyTrackingService, ARSessionDelegate {
    static var isSupported: Bool {
        ARBodyTrackingConfiguration.isSupported
    }

    var onBodyUpdate: (([JointName: SIMD3<Float>], TimeInterval) -> Void)?
    var onError: ((Error) -> Void)?

    /// All joints we want to extract per frame.
    private let trackedJoints: [JointName] = [
        .root, .spine1, .spine3, .spine5, .spine7,
        .neck1, .head,
        .leftShoulder, .leftArm, .leftForearm, .leftHand,
        .rightShoulder, .rightArm, .rightForearm, .rightHand,
        .leftUpLeg, .leftLeg, .leftFoot, .leftToeEnd,
        .rightUpLeg, .rightLeg, .rightFoot, .rightToeEnd,
    ]

    func start(in arView: ARView) {
        let config = ARBodyTrackingConfiguration()
        config.isAutoFocusEnabled = true
        arView.session.delegate = self
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop(in arView: ARView) {
        arView.session.pause()
    }

    // MARK: - ARSessionDelegate

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let body = anchors.compactMap({ $0 as? ARBodyAnchor }).last else { return }

        let rootTransform = body.transform
        let skeleton = body.skeleton
        var positions: [JointName: SIMD3<Float>] = [:]

        for joint in trackedJoints {
            let index = skeleton.definition.index(for: ARSkeleton.JointName(rawValue: joint.jointPath))
            guard index != NSNotFound else { continue }
            let modelT = skeleton.jointModelTransforms[index]
            let worldT = simd_mul(rootTransform, modelT)
            positions[joint] = SIMD3<Float>(worldT.columns.3.x, worldT.columns.3.y, worldT.columns.3.z)
        }

        let timestamp = session.currentFrame?.timestamp ?? CACurrentMediaTime()
        MainActor.assumeIsolated {
            onBodyUpdate?(positions, timestamp)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            onError?(error)
        }
    }
}
