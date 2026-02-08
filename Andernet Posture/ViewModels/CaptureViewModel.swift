//
//  CaptureViewModel.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import Foundation
import SwiftData
import Observation
import simd

/// Drives the PostureGaitCaptureView — orchestrates services, holds live metrics.
@Observable
final class CaptureViewModel {

    // MARK: - Dependencies (protocol-based)

    private let gaitAnalyzer: any GaitAnalyzer
    private let postureAnalyzer: any PostureAnalyzer
    private let motionService: any MotionService
    private let recorder: any SessionRecorder

    // MARK: - Published state

    var recordingState: RecordingState = .idle
    var elapsedTime: TimeInterval = 0

    // Live posture metrics
    var trunkLeanDeg: Double = 0
    var lateralLeanDeg: Double = 0
    var headForwardDeg: Double = 0
    var postureScore: Double = 0

    // Live gait metrics
    var cadenceSPM: Double = 0
    var avgStrideLengthM: Double = 0
    var stepCount: Int = 0
    var symmetryRatio: Double?

    // Calibration
    var isBodyDetected: Bool = false
    var calibrationCountdown: Int = 3

    // Error reporting
    var errorMessage: String?

    // Timer
    private var timer: Timer?

    // MARK: - Init

    init(
        gaitAnalyzer: any GaitAnalyzer = DefaultGaitAnalyzer(),
        postureAnalyzer: any PostureAnalyzer = DefaultPostureAnalyzer(),
        motionService: any MotionService = CoreMotionService(),
        recorder: any SessionRecorder = DefaultSessionRecorder()
    ) {
        self.gaitAnalyzer = gaitAnalyzer
        self.postureAnalyzer = postureAnalyzer
        self.motionService = motionService
        self.recorder = recorder

        setupCallbacks()
    }

    // MARK: - Lifecycle

    /// Start the capture flow (calibration → recording).
    func startCapture() {
        recordingState = .calibrating
        recorder.startCalibration()
        calibrationCountdown = 3
        startTimer()
    }

    /// Toggle pause/resume.
    func togglePause() {
        switch recordingState {
        case .recording:
            recordingState = .paused
            recorder.pause()
            motionService.stop()
            timer?.invalidate()
        case .paused:
            recordingState = .recording
            recorder.resume()
            motionService.start()
            startTimer()
        default:
            break
        }
    }

    /// Stop recording and finalize the session.
    func stopCapture() {
        recorder.stop()
        motionService.stop()
        timer?.invalidate()
        recordingState = .finished
    }

    /// Save the recorded session to SwiftData and optionally HealthKit.
    @MainActor
    func saveSession(context: ModelContext) -> GaitSession? {
        let frames = recorder.collectedFrames()
        let steps = recorder.collectedSteps()

        let trunkLeans = frames.map(\.trunkLeanDeg)
        let lateralLeans = frames.map(\.lateralLeanDeg)
        let sessionScore = postureAnalyzer.computeSessionScore(
            trunkLeans: trunkLeans,
            lateralLeans: lateralLeans
        )

        let session = GaitSession(
            date: .now,
            duration: recorder.elapsedTime,
            averageCadenceSPM: cadenceSPM,
            averageStrideLengthM: avgStrideLengthM,
            averageTrunkLeanDeg: trunkLeans.isEmpty ? nil : trunkLeans.reduce(0, +) / Double(trunkLeans.count),
            postureScore: sessionScore,
            peakTrunkLeanDeg: trunkLeans.max(),
            averageLateralLeanDeg: lateralLeans.isEmpty ? nil : lateralLeans.reduce(0, +) / Double(lateralLeans.count),
            totalSteps: steps.count,
            framesData: GaitSession.encode(frames: frames),
            stepEventsData: GaitSession.encode(stepEvents: steps)
        )

        context.insert(session)
        try? context.save()

        recorder.reset()
        gaitAnalyzer.reset()
        resetMetrics()

        return session
    }

    // MARK: - Private

    private func setupCallbacks() {
        motionService.onMotionUpdate = { [weak self] frame in
            self?.recorder.recordMotionFrame(frame)
        }
    }

    /// Called by BodyARView.Coordinator on each ARBodyAnchor update.
    func handleBodyFrame(joints: [JointName: SIMD3<Float>], timestamp: TimeInterval) {
        isBodyDetected = true

        // Handle calibration → recording transition
        if recordingState == .calibrating {
            calibrationCountdown -= 1
            if calibrationCountdown <= 0 {
                recordingState = .recording
                recorder.startRecording()
                motionService.start()
            }
            return
        }

        guard recordingState == .recording else { return }

        // Posture analysis
        if let postureMetrics = postureAnalyzer.analyze(joints: joints) {
            trunkLeanDeg = postureMetrics.trunkLeanDeg
            lateralLeanDeg = postureMetrics.lateralLeanDeg
            headForwardDeg = postureMetrics.headForwardDeg
            postureScore = postureMetrics.frameScore
        }

        // Gait analysis
        let gaitMetrics = gaitAnalyzer.processFrame(joints: joints, timestamp: timestamp)
        cadenceSPM = gaitMetrics.cadenceSPM
        avgStrideLengthM = gaitMetrics.avgStrideLengthM
        symmetryRatio = gaitMetrics.symmetryRatio

        // Record detected step
        if let strike = gaitMetrics.stepDetected {
            let stepEvent = StepEvent(
                timestamp: strike.timestamp,
                foot: strike.foot,
                positionX: strike.position.x,
                positionZ: strike.position.z,
                strideLengthM: strike.strideLengthM.map(Double.init)
            )
            recorder.recordStep(stepEvent)
            stepCount = recorder.stepCount
        }

        // Record body frame
        let frame = BodyFrame(
            timestamp: timestamp,
            joints: joints,
            trunkLeanDeg: trunkLeanDeg,
            lateralLeanDeg: lateralLeanDeg,
            cadenceSPM: cadenceSPM,
            avgStrideLengthM: avgStrideLengthM
        )
        recorder.recordFrame(frame)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.elapsedTime = self?.recorder.elapsedTime ?? 0
        }
    }

    private func resetMetrics() {
        trunkLeanDeg = 0
        lateralLeanDeg = 0
        headForwardDeg = 0
        postureScore = 0
        cadenceSPM = 0
        avgStrideLengthM = 0
        stepCount = 0
        symmetryRatio = nil
        elapsedTime = 0
        isBodyDetected = false
        recordingState = .idle
    }
}
