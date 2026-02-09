//
//  CaptureViewModel.swift
//  Andernet Posture
//
//  Orchestrates all clinical analyzers, drives PostureGaitCaptureView,
//  and produces comprehensive session analytics.
//

import Foundation
import SwiftData
import Observation
import simd
import UIKit
import os.log

/// Drives the PostureGaitCaptureView — orchestrates services, holds live metrics.
@Observable
final class CaptureViewModel {

    // MARK: - Dependencies (protocol-based)

    private let gaitAnalyzer: any GaitAnalyzer
    private let postureAnalyzer: any PostureAnalyzer
    private let motionService: any MotionService
    private let recorder: any SessionRecorder
    private let balanceAnalyzer: any BalanceAnalyzer
    private let romAnalyzer: any ROMAnalyzer
    private let ergonomicScorer: any ErgonomicScorer
    private let fatigueAnalyzer: any FatigueAnalyzer
    private let smoothnessAnalyzer: any SmoothnessAnalyzer
    private let fallRiskAnalyzer: any FallRiskAnalyzer
    private let gaitPatternClassifier: any GaitPatternClassifier
    private let crossedSyndromeDetector: any CrossedSyndromeDetector
    private let painRiskEngine: any PainRiskEngine
    private let frailtyScreener: any FrailtyScreener
    private let cardioEstimator: any CardioEstimator
    private let healthKitService: any HealthKitService

    // MARK: - Published state

    var recordingState: RecordingState = .idle
    var elapsedTime: TimeInterval = 0

    // Live posture metrics
    var trunkLeanDeg: Double = 0
    var lateralLeanDeg: Double = 0
    var headForwardDeg: Double = 0
    var postureScore: Double = 0

    // Clinical posture (live)
    var craniovertebralAngleDeg: Double = 0
    var sagittalVerticalAxisCm: Double = 0
    var thoracicKyphosisDeg: Double = 0
    var lumbarLordosisDeg: Double = 0
    var shoulderAsymmetryCm: Double = 0
    var pelvicObliquityDeg: Double = 0
    var kendallType: PosturalType = .ideal
    var nyprScore: Int = 0

    // Live gait metrics
    var cadenceSPM: Double = 0
    var avgStrideLengthM: Double = 0
    var stepCount: Int = 0
    var symmetryPercent: Double?
    var walkingSpeedMPS: Double = 0
    var avgStepWidthCm: Double = 0

    // Live balance
    var swayVelocityMMS: Double = 0
    var isStanding: Bool = false

    // Live ROM
    var hipFlexionLeftDeg: Double = 0
    var hipFlexionRightDeg: Double = 0
    var kneeFlexionLeftDeg: Double = 0
    var kneeFlexionRightDeg: Double = 0

    // Live REBA
    var rebaScore: Int = 1

    // Calibration
    var isBodyDetected: Bool = false
    var calibrationCountdown: Int = 3

    // Calibration timer (time-based, not frame-based)
    private var calibrationStartTime: TimeInterval?

    // Error reporting
    var errorMessage: String?

    // Per-frame severity map (latest)
    var severities: [String: ClinicalSeverity] = [:]

    // Timer
    private var timer: Timer?

    // Frame counter for throttling expensive computations
    private var frameIndex: Int = 0

    // Haptic feedback
    @ObservationIgnored private let hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
    @ObservationIgnored private var hapticEnabled: Bool { UserDefaults.standard.bool(forKey: "hapticFeedback") }
    private var lastHapticFrame: Int = 0

    // Cached ROM values for frames when ROM analysis is throttled
    private var cachedROMValues: (
        hipL: Double, hipR: Double, kneeL: Double, kneeR: Double,
        pelvicTilt: Double, trunkRot: Double, armSwingL: Double, armSwingR: Double
    )?

    // Session accumulators
    private var postureMetricsHistory: [PostureMetrics] = []
    private var stepWidthValues: [Double] = []

    // MARK: - Init

    init(
        gaitAnalyzer: any GaitAnalyzer = DefaultGaitAnalyzer(),
        postureAnalyzer: any PostureAnalyzer = DefaultPostureAnalyzer(),
        motionService: any MotionService = CoreMotionService(),
        recorder: any SessionRecorder = DefaultSessionRecorder(),
        balanceAnalyzer: any BalanceAnalyzer = DefaultBalanceAnalyzer(),
        romAnalyzer: any ROMAnalyzer = DefaultROMAnalyzer(),
        ergonomicScorer: any ErgonomicScorer = DefaultErgonomicScorer(),
        fatigueAnalyzer: any FatigueAnalyzer = DefaultFatigueAnalyzer(),
        smoothnessAnalyzer: any SmoothnessAnalyzer = DefaultSmoothnessAnalyzer(),
        fallRiskAnalyzer: any FallRiskAnalyzer = DefaultFallRiskAnalyzer(),
        gaitPatternClassifier: any GaitPatternClassifier = DefaultGaitPatternClassifier(),
        crossedSyndromeDetector: any CrossedSyndromeDetector = DefaultCrossedSyndromeDetector(),
        painRiskEngine: any PainRiskEngine = DefaultPainRiskEngine(),
        frailtyScreener: any FrailtyScreener = DefaultFrailtyScreener(),
        cardioEstimator: any CardioEstimator = DefaultCardioEstimator(),
        healthKitService: any HealthKitService = DefaultHealthKitService()
    ) {
        self.gaitAnalyzer = gaitAnalyzer
        self.postureAnalyzer = postureAnalyzer
        self.motionService = motionService
        self.recorder = recorder
        self.balanceAnalyzer = balanceAnalyzer
        self.romAnalyzer = romAnalyzer
        self.ergonomicScorer = ergonomicScorer
        self.fatigueAnalyzer = fatigueAnalyzer
        self.smoothnessAnalyzer = smoothnessAnalyzer
        self.fallRiskAnalyzer = fallRiskAnalyzer
        self.gaitPatternClassifier = gaitPatternClassifier
        self.crossedSyndromeDetector = crossedSyndromeDetector
        self.painRiskEngine = painRiskEngine
        self.frailtyScreener = frailtyScreener
        self.cardioEstimator = cardioEstimator
        self.healthKitService = healthKitService

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

    /// Save the recorded session to SwiftData with full clinical analytics.
    @MainActor
    // swiftlint:disable:next function_body_length
    func saveSession(context: ModelContext) -> GaitSession? {
        let saveToken = PerformanceMonitor.begin(.sessionSave)
        defer { PerformanceMonitor.end(saveToken) }

        let frames = recorder.collectedFrames()
        let steps = recorder.collectedSteps()
        let motionFrames = recorder.collectedMotionFrames()

        let trunkLeans = frames.map(\.sagittalTrunkLeanDeg)
        let lateralLeans = frames.map(\.frontalTrunkLeanDeg)
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
            stepEventsData: GaitSession.encode(stepEvents: steps),
            motionFramesData: GaitSession.encode(motionFrames: motionFrames)
        )

        // Clinical posture averages
        if !postureMetricsHistory.isEmpty {
            let n = Double(postureMetricsHistory.count)
            session.averageCVADeg = postureMetricsHistory.map(\.craniovertebralAngleDeg).reduce(0, +) / n
            session.averageSVACm = postureMetricsHistory.map(\.sagittalVerticalAxisCm).reduce(0, +) / n
            session.averageThoracicKyphosisDeg = postureMetricsHistory.map(\.thoracicKyphosisDeg).reduce(0, +) / n
            session.averageLumbarLordosisDeg = postureMetricsHistory.map(\.lumbarLordosisDeg).reduce(0, +) / n
            session.averageShoulderAsymmetryCm = postureMetricsHistory.map(\.shoulderAsymmetryCm).reduce(0, +) / n
            session.averagePelvicObliquityDeg = postureMetricsHistory.map(\.pelvicObliquityDeg).reduce(0, +) / n
            session.averageCoronalDeviationCm = postureMetricsHistory.map(\.coronalSpineDeviationCm).reduce(0, +) / n
            session.kendallPosturalType = postureMetricsHistory.last?.posturalType.rawValue
            session.nyprScore = postureMetricsHistory.last?.nyprScore
        }

        // Gait metrics
        session.averageWalkingSpeedMPS = walkingSpeedMPS
        session.averageStepWidthCm = avgStepWidthCm
        session.gaitAsymmetryPercent = symmetryPercent

        // ROM session summary
        let romSummary = romAnalyzer.sessionSummary()
        session.averageHipROMDeg = (romSummary.hipROMLeftDeg + romSummary.hipROMRightDeg) / 2
        session.averageKneeROMDeg = (romSummary.kneeROMLeftDeg + romSummary.kneeROMRightDeg) / 2
        session.trunkRotationRangeDeg = romSummary.trunkRotationRangeDeg
        session.armSwingAsymmetryPercent = romSummary.armSwingAsymmetryPercent

        // Fatigue analysis
        let fatigue = fatigueAnalyzer.assess()
        session.fatigueIndex = fatigue.fatigueIndex
        session.postureVariabilitySD = fatigue.postureVariabilitySD
        session.postureFatigueTrend = fatigue.postureTrendSlope

        // REBA
        session.rebaScore = rebaScore

        // Smoothness
        let smoothness = smoothnessAnalyzer.analyze()
        session.sparcScore = smoothness.sparcScore
        session.harmonicRatio = smoothness.harmonicRatioAP

        // Cardio estimate
        let cardio = cardioEstimator.estimate(
            walkingSpeedMPS: walkingSpeedMPS,
            cadenceSPM: cadenceSPM,
            strideLengthM: avgStrideLengthM
        )
        session.estimatedMET = cardio.estimatedMET
        session.walkRatio = cardio.walkRatio

        // Fall risk
        let stepWidthSD = standardDeviation(stepWidthValues)
        let fallRisk = fallRiskAnalyzer.assess(
            walkingSpeedMPS: walkingSpeedMPS,
            strideTimeCVPercent: nil, // From gait analyzer, already handled per-frame
            doubleSupportPercent: nil,
            stepWidthVariabilityCm: stepWidthSD,
            swayVelocityMMS: swayVelocityMMS,
            stepAsymmetryPercent: symmetryPercent,
            tugTimeSec: nil,
            footClearanceM: nil
        )
        session.fallRiskScore = fallRisk.compositeScore
        session.fallRiskLevel = fallRisk.riskLevel.rawValue

        // Gait pattern
        let gaitPattern = gaitPatternClassifier.classify(
            stanceTimeLeftPercent: nil, stanceTimeRightPercent: nil,
            stepLengthLeftM: nil, stepLengthRightM: nil,
            cadenceSPM: cadenceSPM,
            avgStepWidthCm: avgStepWidthCm,
            stepWidthVariabilityCm: stepWidthSD,
            pelvicObliquityDeg: pelvicObliquityDeg,
            strideTimeCVPercent: nil,
            walkingSpeedMPS: walkingSpeedMPS,
            strideLengthM: avgStrideLengthM,
            hipFlexionROMDeg: romSummary.hipROMLeftDeg,
            armSwingAsymmetryPercent: romSummary.armSwingAsymmetryPercent,
            kneeFlexionROMDeg: max(romSummary.kneeROMLeftDeg, romSummary.kneeROMRightDeg)
        )
        session.gaitPatternClassification = gaitPattern.primaryPattern.rawValue

        // Crossed syndrome
        let crossed = crossedSyndromeDetector.detect(
            craniovertebralAngleDeg: session.averageCVADeg ?? 52,
            shoulderProtractionCm: 0, // Would need shoulder-C7 offset average
            thoracicKyphosisDeg: session.averageThoracicKyphosisDeg ?? 30,
            cervicalLordosisDeg: nil,
            pelvicTiltDeg: frames.isEmpty ? 0 : frames.map(\.pelvicTiltDeg).reduce(0, +) / Double(frames.count),
            lumbarLordosisDeg: session.averageLumbarLordosisDeg ?? 50,
            hipFlexionRestDeg: nil
        )
        session.upperCrossedScore = crossed.upperCrossedScore
        session.lowerCrossedScore = crossed.lowerCrossedScore

        // Pain risk
        let painRisk = painRiskEngine.assess(
            craniovertebralAngleDeg: session.averageCVADeg ?? 52,
            sagittalVerticalAxisCm: session.averageSVACm ?? 0,
            thoracicKyphosisDeg: session.averageThoracicKyphosisDeg ?? 30,
            lumbarLordosisDeg: session.averageLumbarLordosisDeg ?? 50,
            shoulderAsymmetryCm: session.averageShoulderAsymmetryCm ?? 0,
            pelvicObliquityDeg: session.averagePelvicObliquityDeg ?? 0,
            pelvicTiltDeg: frames.isEmpty ? 0 : frames.map(\.pelvicTiltDeg).reduce(0, +) / Double(frames.count),
            coronalSpineDeviationCm: session.averageCoronalDeviationCm ?? 0,
            kneeFlexionStandingDeg: nil,
            gaitAsymmetryPercent: symmetryPercent
        )
        session.painRiskAlertsData = try? JSONEncoder().encode(painRisk.alerts)

        context.insert(session)
        try? context.save()

        // HealthKit auto-save
        if UserDefaults.standard.bool(forKey: "healthKitSync") {
            let hkService = healthKitService
            let steps = session.totalSteps ?? 0
            let speed = session.averageWalkingSpeedMPS
            let stride = session.averageStrideLengthM
            let asymmetry = session.gaitAsymmetryPercent.map { $0 / 100.0 }
            let distance: Double? = nil  // Not directly tracked as raw distance
            let start = session.date.addingTimeInterval(-session.duration)
            let end = session.date
            Task {
                do {
                    try await hkService.saveSession(
                        steps: steps,
                        walkingSpeed: speed,
                        strideLength: stride,
                        asymmetry: asymmetry,
                        distance: distance,
                        start: start,
                        end: end
                    )
                    AppLogger.healthKit.info("HealthKit session auto-save succeeded")
                } catch {
                    AppLogger.healthKit.error("HealthKit session auto-save failed: \(error.localizedDescription)")
                }
            }
        }

        recorder.reset()
        gaitAnalyzer.reset()
        balanceAnalyzer.reset()
        romAnalyzer.reset()
        fatigueAnalyzer.reset()
        smoothnessAnalyzer.reset()
        resetMetrics()

        return session
    }

    // MARK: - Private

    private func setupCallbacks() {
        motionService.onMotionUpdate = { [weak self] frame in
            self?.recorder.recordMotionFrame(frame)
            // Feed accelerometer to smoothness analyzer
            self?.smoothnessAnalyzer.recordSample(
                timestamp: frame.timestamp,
                accelerationAP: frame.userAccelerationZ,
                accelerationML: frame.userAccelerationX,
                accelerationV: frame.userAccelerationY
            )
        }
    }

    // swiftlint:disable:next orphaned_doc_comment
    /// Called by BodyARView.Coordinator on each ARBodyAnchor update.
    // swiftlint:disable:next function_body_length
    func handleBodyFrame(joints: [JointName: SIMD3<Float>], timestamp: TimeInterval) {
        let frameToken = PerformanceMonitor.begin(.frameProcessing)
        defer { PerformanceMonitor.end(frameToken) }

        isBodyDetected = true

        // Handle calibration → recording transition (time-based: 3 seconds)
        if recordingState == .calibrating {
            if calibrationStartTime == nil {
                calibrationStartTime = timestamp
            }
            let elapsed = timestamp - (calibrationStartTime ?? timestamp)
            calibrationCountdown = max(0, 3 - Int(elapsed))
            if elapsed >= 3.0 {
                calibrationStartTime = nil
                recordingState = .recording
                recorder.startRecording()
                motionService.start()
            }
            return
        }

        guard recordingState == .recording else { return }
        frameIndex += 1

        // ── Posture analysis ──
        var currentPosture: PostureMetrics?
        if let postureMetrics = PerformanceMonitor.measure(.postureAnalysis, body: { postureAnalyzer.analyze(joints: joints) }) {
            currentPosture = postureMetrics
            trunkLeanDeg = postureMetrics.sagittalTrunkLeanDeg
            lateralLeanDeg = postureMetrics.frontalTrunkLeanDeg
            headForwardDeg = postureMetrics.headForwardDeg
            postureScore = postureMetrics.postureScore
            craniovertebralAngleDeg = postureMetrics.craniovertebralAngleDeg
            sagittalVerticalAxisCm = postureMetrics.sagittalVerticalAxisCm
            thoracicKyphosisDeg = postureMetrics.thoracicKyphosisDeg
            lumbarLordosisDeg = postureMetrics.lumbarLordosisDeg
            shoulderAsymmetryCm = postureMetrics.shoulderAsymmetryCm
            pelvicObliquityDeg = postureMetrics.pelvicObliquityDeg
            kendallType = postureMetrics.posturalType
            nyprScore = postureMetrics.nyprScore
            severities = postureMetrics.severities
            postureMetricsHistory.append(postureMetrics)

            // ── Haptic alert for poor posture ──
            if hapticEnabled && postureMetrics.postureScore < 40 && frameIndex - lastHapticFrame > 120 {
                hapticGenerator.impactOccurred()
                lastHapticFrame = frameIndex
            }
        }

        // ── Gait analysis ──
        let gaitMetrics = PerformanceMonitor.measure(.gaitAnalysis) {
            gaitAnalyzer.processFrame(joints: joints, timestamp: timestamp)
        }
        cadenceSPM = gaitMetrics.cadenceSPM
        avgStrideLengthM = gaitMetrics.avgStrideLengthM
        symmetryPercent = gaitMetrics.symmetryPercent
        walkingSpeedMPS = gaitMetrics.walkingSpeedMPS
        avgStepWidthCm = gaitMetrics.avgStepWidthCm

        // ── ROM analysis (every 3rd frame) ──
        if frameIndex % 3 == 0 {
            let romMetrics = PerformanceMonitor.measure(.romAnalysis) {
                romAnalyzer.analyze(joints: joints)
            }
            romAnalyzer.recordFrame(romMetrics)
            hipFlexionLeftDeg = romMetrics.hipFlexionLeftDeg
            hipFlexionRightDeg = romMetrics.hipFlexionRightDeg
            kneeFlexionLeftDeg = romMetrics.kneeFlexionLeftDeg
            kneeFlexionRightDeg = romMetrics.kneeFlexionRightDeg
            cachedROMValues = (
                hipL: romMetrics.hipFlexionLeftDeg,
                hipR: romMetrics.hipFlexionRightDeg,
                kneeL: romMetrics.kneeFlexionLeftDeg,
                kneeR: romMetrics.kneeFlexionRightDeg,
                pelvicTilt: romMetrics.pelvicTiltDeg,
                trunkRot: romMetrics.trunkRotationDeg,
                armSwingL: romMetrics.armSwingLeftDeg,
                armSwingR: romMetrics.armSwingRightDeg
            )
        }

        // ── Balance analysis (every 2nd frame) ──
        if frameIndex % 2 == 0 {
            if let root = joints[.root] {
                let balanceMetrics = PerformanceMonitor.measure(.balanceAnalysis) {
                    balanceAnalyzer.processFrame(rootPosition: root, timestamp: timestamp)
                }
                swayVelocityMMS = balanceMetrics.swayVelocityMMS
                isStanding = balanceAnalyzer.isStanding
            }
        }

        // ── REBA (throttled — every 10th frame) ──
        if frameIndex % 10 == 0 {
            let reba = PerformanceMonitor.measure(.ergonomicScoring) {
                ergonomicScorer.computeREBA(joints: joints)
            }
            rebaScore = reba.score
        }

        // ── Fatigue tracking (every 6th frame) ──
        if frameIndex % 6 == 0 {
            PerformanceMonitor.measure(.fatigueTracking) {
                fatigueAnalyzer.recordTimePoint(
                    timestamp: timestamp,
                    postureScore: postureScore,
                    trunkLeanDeg: trunkLeanDeg,
                    lateralLeanDeg: lateralLeanDeg,
                    cadenceSPM: cadenceSPM,
                    walkingSpeedMPS: walkingSpeedMPS
                )
            }
        }

        // ── Record detected step ──
        if let strike = gaitMetrics.stepDetected {
            let stepEvent = StepEvent(
                timestamp: strike.timestamp,
                foot: strike.foot,
                positionX: strike.position.x,
                positionZ: strike.position.z,
                strideLengthM: strike.strideLengthM.map(Double.init),
                stepLengthM: strike.stepLengthM.map(Double.init),
                stepWidthCm: strike.stepWidthCm.map(Double.init),
                impactVelocity: strike.impactVelocity.map(Double.init),
                footClearanceM: strike.footClearanceM.map(Double.init)
            )
            recorder.recordStep(stepEvent)
            stepCount = recorder.stepCount

            if let sw = strike.stepWidthCm {
                stepWidthValues.append(Double(sw))
            }
        }

        // ── Record body frame ──
        PerformanceMonitor.measure(.frameRecording) {
            let frame = BodyFrame(
            timestamp: timestamp,
            joints: joints,
            sagittalTrunkLeanDeg: trunkLeanDeg,
            frontalTrunkLeanDeg: lateralLeanDeg,
            craniovertebralAngleDeg: craniovertebralAngleDeg,
            sagittalVerticalAxisCm: sagittalVerticalAxisCm,
            shoulderAsymmetryCm: shoulderAsymmetryCm,
            shoulderTiltDeg: currentPosture?.shoulderTiltDeg ?? 0,
            pelvicObliquityDeg: pelvicObliquityDeg,
            thoracicKyphosisDeg: thoracicKyphosisDeg,
            lumbarLordosisDeg: lumbarLordosisDeg,
            coronalSpineDeviationCm: currentPosture?.coronalSpineDeviationCm ?? 0,
            posturalType: kendallType.rawValue,
            nyprScore: nyprScore,
            postureScore: postureScore,
            cadenceSPM: cadenceSPM,
            avgStrideLengthM: avgStrideLengthM,
            walkingSpeedMPS: walkingSpeedMPS,
            stepWidthCm: avgStepWidthCm,
            hipFlexionLeftDeg: cachedROMValues?.hipL ?? hipFlexionLeftDeg,
            hipFlexionRightDeg: cachedROMValues?.hipR ?? hipFlexionRightDeg,
            kneeFlexionLeftDeg: cachedROMValues?.kneeL ?? kneeFlexionLeftDeg,
            kneeFlexionRightDeg: cachedROMValues?.kneeR ?? kneeFlexionRightDeg,
            pelvicTiltDeg: cachedROMValues?.pelvicTilt ?? 0,
            trunkRotationDeg: cachedROMValues?.trunkRot ?? 0,
            armSwingLeftDeg: cachedROMValues?.armSwingL ?? 0,
            armSwingRightDeg: cachedROMValues?.armSwingR ?? 0,
            swayVelocityMMS: swayVelocityMMS,
            rebaScore: frameIndex % 10 == 0 ? rebaScore : nil,
            gaitPatternRaw: nil
        )
        recorder.recordFrame(frame)
        }
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
        craniovertebralAngleDeg = 0
        sagittalVerticalAxisCm = 0
        thoracicKyphosisDeg = 0
        lumbarLordosisDeg = 0
        shoulderAsymmetryCm = 0
        pelvicObliquityDeg = 0
        kendallType = .ideal
        nyprScore = 0
        cadenceSPM = 0
        avgStrideLengthM = 0
        stepCount = 0
        symmetryPercent = nil
        walkingSpeedMPS = 0
        avgStepWidthCm = 0
        swayVelocityMMS = 0
        isStanding = false
        hipFlexionLeftDeg = 0
        hipFlexionRightDeg = 0
        kneeFlexionLeftDeg = 0
        kneeFlexionRightDeg = 0
        rebaScore = 1
        elapsedTime = 0
        isBodyDetected = false
        recordingState = .idle
        severities = [:]
        frameIndex = 0
        lastHapticFrame = 0
        cachedROMValues = nil
        calibrationStartTime = nil
        postureMetricsHistory.removeAll()
        stepWidthValues.removeAll()
    }
}
