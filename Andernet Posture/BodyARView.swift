//
//  BodyARView.swift
//  Andernet Posture
//
//  Thin UIViewRepresentable wrapper around ARView.
//  Skeleton overlay and frame-rate throttling are driven by
//  @AppStorage values passed in from PostureGaitCaptureView.
//

import SwiftUI
import RealityKit
import ARKit
import QuartzCore
import os.log

struct BodyARView: UIViewRepresentable {
    let viewModel: CaptureViewModel
    /// Whether the skeleton overlay is visible (driven by @AppStorage "skeletonOverlay").
    var showSkeleton: Bool = true
    /// Target sampling rate in Hz (driven by @AppStorage "samplingRate").
    var samplingRate: Double = 60.0

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, showSkeleton: showSkeleton, samplingRate: samplingRate)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        guard ARBodyTrackingConfiguration.isSupported else {
            AppLogger.arTracking.warning("ARBodyTrackingConfiguration not supported on this device.")
            return arView
        }

        let config = ARBodyTrackingConfiguration()
        config.isAutoFocusEnabled = true
        config.frameSemantics.insert(.bodyDetection)
        arView.session.delegate = context.coordinator
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        arView.environment.sceneUnderstanding.options = []

        // Add skeleton anchor
        context.coordinator.setupSkeletonOverlay(in: arView)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.showSkeleton = showSkeleton
        context.coordinator.samplingRate = samplingRate
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }
}

// MARK: - Coordinator (ARSession delegate, skeleton overlay)

extension BodyARView {
    final class Coordinator: NSObject, ARSessionDelegate {
        private let viewModel: CaptureViewModel
        private var bodyAnchorEntity: AnchorEntity?
        private var jointEntities: [JointName: ModelEntity] = [:]
        private var boneEntities: [(ModelEntity, JointName, JointName)] = []

        /// Toggled by `updateUIView` when the @AppStorage value changes.
        var showSkeleton: Bool
        /// Target sampling rate (Hz). Frames are skipped to approximate this rate.
        var samplingRate: Double
        /// Tracks the last timestamp forwarded to the view-model for frame-rate throttling.
        private var lastForwardedTimestamp: TimeInterval = 0

        init(viewModel: CaptureViewModel, showSkeleton: Bool, samplingRate: Double) {
            self.viewModel = viewModel
            self.showSkeleton = showSkeleton
            self.samplingRate = samplingRate
        }

        // MARK: Skeleton overlay

        func setupSkeletonOverlay(in arView: ARView) {
            let anchor = AnchorEntity()
            arView.scene.addAnchor(anchor)
            bodyAnchorEntity = anchor

            // Create sphere entities for each tracked joint
            let jointMaterial = SimpleMaterial(color: .systemCyan.withAlphaComponent(0.8), isMetallic: false)
            let jointMesh = MeshResource.generateSphere(radius: 0.025)

            for joint in JointName.allCases {
                let entity = ModelEntity(mesh: jointMesh, materials: [jointMaterial])
                entity.isEnabled = false
                anchor.addChild(entity)
                jointEntities[joint] = entity
            }

            // Create cylinder entities for bone connections
            let boneMaterial = SimpleMaterial(color: .systemTeal.withAlphaComponent(0.6), isMetallic: false)
            for (from, to) in JointName.skeletonConnections {
                let entity = ModelEntity(
                    mesh: MeshResource.generateBox(size: [0.01, 0.01, 0.01]),
                    materials: [boneMaterial]
                )
                entity.isEnabled = false
                anchor.addChild(entity)
                boneEntities.append((entity, from, to))
            }
        }

        // MARK: ARSessionDelegate

        nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let body = anchors.compactMap({ $0 as? ARBodyAnchor }).last else { return }
            let rootTransform = body.transform

            var joints: [JointName: SIMD3<Float>] = [:]

            for joint in JointName.allCases {
                let path = joint.jointPath
                let skeleton = body.skeleton
                let idx = skeleton.definition.index(for: ARSkeleton.JointName(rawValue: path))
                guard idx != NSNotFound else { continue }
                let modelT = skeleton.jointModelTransforms[idx]
                let worldT = simd_mul(rootTransform, modelT)
                let pos = SIMD3<Float>(worldT.columns.3.x, worldT.columns.3.y, worldT.columns.3.z)
                joints[joint] = pos
            }

            let timestamp = session.currentFrame?.timestamp ?? CACurrentMediaTime()

            MainActor.assumeIsolated {
                // Frame-rate throttling: skip frames when samplingRate < 60
                let minInterval = samplingRate > 0 ? (1.0 / samplingRate) : 0
                if timestamp - lastForwardedTimestamp >= minInterval {
                    lastForwardedTimestamp = timestamp
                    viewModel.handleBodyFrame(joints: joints, timestamp: timestamp)
                }

                // Update skeleton overlay (respects showSkeleton toggle)
                updateSkeletonOverlay(joints: joints)
            }
        }

        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            AppLogger.arTracking.error("AR session failed: \(error.localizedDescription)")
            MainActor.assumeIsolated {
                viewModel.errorMessage = error.localizedDescription
            }
        }

        // MARK: Private — skeleton visualization

        private func updateSkeletonOverlay(joints: [JointName: SIMD3<Float>]) {
            // If skeleton overlay is disabled, hide everything and return early
            guard showSkeleton else {
                for (_, entity) in jointEntities { entity.isEnabled = false }
                for (entity, _, _) in boneEntities { entity.isEnabled = false }
                return
            }

            for (joint, entity) in jointEntities {
                if let pos = joints[joint] {
                    entity.position = pos
                    entity.isEnabled = true
                } else {
                    entity.isEnabled = false
                }
            }

            for (entity, from, to) in boneEntities {
                guard let fromPos = joints[from], let toPos = joints[to] else {
                    entity.isEnabled = false
                    continue
                }
                let mid = (fromPos + toPos) / 2
                let diff = toPos - fromPos
                let length = simd_length(diff)

                guard length > 0.001 else {
                    entity.isEnabled = false
                    continue
                }

                entity.position = mid
                entity.scale = SIMD3<Float>(0.008, 0.008, length)

                // Orient cylinder along the bone direction
                let dir = simd_normalize(diff)
                let defaultDir = SIMD3<Float>(0, 0, 1) // box extends along Z
                let cross = simd_cross(defaultDir, dir)
                let dot = simd_dot(defaultDir, dir)
                if simd_length(cross) > 0.0001 {
                    let angle = acos(simd_clamp(dot, -1, 1))
                    entity.orientation = simd_quatf(angle: angle, axis: simd_normalize(cross))
                } else if dot < 0 {
                    entity.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                } else {
                    entity.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                }
                entity.isEnabled = true
            }
        }
    }
}
