import SwiftUI
import RealityKit
import ARKit
import simd

final class MetricsModel: ObservableObject {
    @Published var trunkLeanDegrees: Double = 0
    @Published var cadenceSPM: Double = 0
    @Published var avgStrideLengthM: Double = 0
}

struct BodyARView: UIViewRepresentable {
    @ObservedObject var metrics: MetricsModel

    func makeCoordinator() -> Coordinator {
        Coordinator(metrics: metrics)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        guard ARBodyTrackingConfiguration.isSupported else {
            print("ARBodyTrackingConfiguration not supported on this device.")
            return arView
        }

        let config = ARBodyTrackingConfiguration()
        config.isAutoFocusEnabled = true
        arView.session.delegate = context.coordinator
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

extension BodyARView {
    final class Coordinator: NSObject, ARSessionDelegate {
        private let metrics: MetricsModel

        private var lastLeftAnkleYs: [Float] = []
        private var lastRightAnkleYs: [Float] = []
        private var lastLeftStepTime: CFTimeInterval?
        private var lastRightStepTime: CFTimeInterval?
        private var stepTimestamps: [CFTimeInterval] = []
        private var lastLeftFootXZ: SIMD2<Float>?
        private var lastRightFootXZ: SIMD2<Float>?
        private var strideLengths: [Float] = []

        init(metrics: MetricsModel) {
            self.metrics = metrics
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let body = anchors.compactMap({ $0 as? ARBodyAnchor }).last else { return }

            let rootTransform = body.transform

            func worldPosition(_ name: ARSkeleton.JointName) -> SIMD3<Float>? {
                let skeleton = body.skeleton
                guard let index = skeleton.definition.index(for: name) else { return nil }
                let modelT = skeleton.jointModelTransforms[index]
                let worldT = simd_mul(rootTransform, modelT)
                return SIMD3<Float>(worldT.columns.3.x, worldT.columns.3.y, worldT.columns.3.z)
            }

            guard
                let hips = worldPosition(.root),
                let neck = worldPosition(.neck_1)
            else { return }

            let torso = simd_normalize(neck - hips)
            let up = SIMD3<Float>(0, 1, 0)
            let cosTheta = simd_clamp(simd_dot(torso, up), -1, 1)
            let angleRad = acos(cosTheta)
            let angleDeg = Double(angleRad * 180 / .pi)

            DispatchQueue.main.async {
                self.metrics.trunkLeanDegrees = angleDeg
            }

            if let la = worldPosition(.left_foot), let ra = worldPosition(.right_foot) {
                processGait(la: la, ra: ra, timestamp: session.currentFrame?.timestamp ?? CACurrentMediaTime())
            }
        }

        private func processGait(la: SIMD3<Float>, ra: SIMD3<Float>, timestamp: CFTimeInterval) {
            lastLeftAnkleYs.append(la.y)
            lastRightAnkleYs.append(ra.y)
            if lastLeftAnkleYs.count > 15 { lastLeftAnkleYs.removeFirst() }
            if lastRightAnkleYs.count > 15 { lastRightAnkleYs.removeFirst() }

            func isLocalMin(_ arr: [Float]) -> Bool {
                guard arr.count >= 5 else { return false }
                let i = arr.count - 3
                let a = arr[i-1], b = arr[i], c = arr[i+1]
                return b < a && b < c
            }

            if isLocalMin(lastLeftAnkleYs) {
                if let prev = lastLeftStepTime {
                    let _ = timestamp - prev
                    stepTimestamps.append(timestamp)
                    updateCadence()
                    if let prevXZ = lastLeftFootXZ {
                        let curXZ = SIMD2<Float>(la.x, la.z)
                        let stride = simd_length(curXZ - prevXZ)
                        strideLengths.append(stride)
                        updateStride()
                    }
                }
                lastLeftStepTime = timestamp
                lastLeftFootXZ = SIMD2<Float>(la.x, la.z)
            }

            if isLocalMin(lastRightAnkleYs) {
                if let prev = lastRightStepTime {
                    let _ = timestamp - prev
                    stepTimestamps.append(timestamp)
                    updateCadence()
                    if let prevXZ = lastRightFootXZ {
                        let curXZ = SIMD2<Float>(ra.x, ra.z)
                        let stride = simd_length(curXZ - prevXZ)
                        strideLengths.append(stride)
                        updateStride()
                    }
                }
                lastRightStepTime = timestamp
                lastRightFootXZ = SIMD2<Float>(ra.x, ra.z)
            }
        }

        private func updateCadence() {
            let window: CFTimeInterval = 10
            guard let latest = stepTimestamps.last else { return }
            let recent = stepTimestamps.filter { latest - $0 <= window }
            let stepsPerSecond = Double(recent.count) / window
            let spm = stepsPerSecond * 60.0
            DispatchQueue.main.async {
                self.metrics.cadenceSPM = spm
            }
        }

        private func updateStride() {
            let n = max(1, strideLengths.count)
            let avg = strideLengths.reduce(0, +) / Float(n)
            DispatchQueue.main.async {
                self.metrics.avgStrideLengthM = Double(avg)
            }
        }
    }
}
