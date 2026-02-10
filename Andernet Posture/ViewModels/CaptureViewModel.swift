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
    private let pedometerService: any PedometerService
    private let imuStepDetector: any IMUStepDetector
    private let trunkMotionAnalyzer: any TrunkMotionAnalyzer

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

    // IMU-derived live metrics
    var imuCadenceSPM: Double = 0
    var imuStepCount: Int = 0
    var imuSwayRmsML: Double = 0
    var imuSwayRmsAP: Double = 0

    // Pedometer live metrics
    var pedometerDistanceM: Double = 0
    var pedometerStepCount: Int = 0
    var pedometerCadenceSPM: Double = 0

    // Distance accumulation (best available)
    var totalDistanceM: Double = 0

    // Trunk motion live metrics
    var trunkRotationVelocityDPS: Double = 0
    var turnCount: Int = 0

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

    // Distance accumulation from ARKit root displacement
    private var lastRootPosition: SIMD3<Float>?
    private var accumulatedARKitDistanceM: Double = 0

    // MARK: - Init

    init(
        gaitAnalyzer: any GaitAnalyzer = DefaultGaitAnalyzer(),
        postureAnalyzer: any PostureAnalyzer = CoreMLPostureAnalyzer(modelService: .shared),
        motionService: any MotionService = CoreMotionService(),
        recorder: any SessionRecorder = DefaultSessionRecorder(),
        balanceAnalyzer: any BalanceAnalyzer = DefaultBalanceAnalyzer(),
        romAnalyzer: any ROMAnalyzer = DefaultROMAnalyzer(),
        ergonomicScorer: any ErgonomicScorer = DefaultErgonomicScorer(),
        fatigueAnalyzer: any FatigueAnalyzer = CoreMLFatigueAnalyzer(modelService: .shared),
        smoothnessAnalyzer: any SmoothnessAnalyzer = DefaultSmoothnessAnalyzer(),
        fallRiskAnalyzer: any FallRiskAnalyzer = CoreMLFallRiskAnalyzer(modelService: .shared),
        gaitPatternClassifier: any GaitPatternClassifier = CoreMLGaitPatternClassifier(modelService: .shared),
        crossedSyndromeDetector: any CrossedSyndromeDetector = CoreMLCrossedSyndromeDetector(modelService: .shared),
        painRiskEngine: any PainRiskEngine = DefaultPainRiskEngine(),
        frailtyScreener: any FrailtyScreener = DefaultFrailtyScreener(),
        cardioEstimator: any CardioEstimator = DefaultCardioEstimator(),
        healthKitService: any HealthKitService = DefaultHealthKitService(),
        pedometerService: any PedometerService = CorePedometerService(),
        imuStepDetector: any IMUStepDetector = DefaultIMUStepDetector(),
        trunkMotionAnalyzer: any TrunkMotionAnalyzer = DefaultTrunkMotionAnalyzer()
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
        self.pedometerService = pedometerService
        self.imuStepDetector = imuStepDetector
        self.trunkMotionAnalyzer = trunkMotionAnalyzer

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
            pedometerService.stop()
            timer?.invalidate()
        case .paused:
            recordingState = .recording
            recorder.resume()
            motionService.start()
            pedometerService.startLiveUpdates()
            startTimer()
        default:
            break
        }
    }

    /// Stop recording and finalize the session.
    func stopCapture() {
        recorder.stop()
        motionService.stop()
        pedometerService.stop()
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

        // Distance tracking (sensor-derived)
        session.totalDistanceM = totalDistanceM
        session.pedometerDistanceM = pedometerDistanceM > 0 ? pedometerDistanceM : nil
        session.pedometerStepCount = pedometerStepCount > 0 ? pedometerStepCount : nil
        if let snapshot = pedometerService.latestSnapshot {
            session.floorsAscended = snapshot.floorsAscended
            session.floorsDescended = snapshot.floorsDescended
        }

        // IMU-derived metrics
        session.imuCadenceSPM = imuCadenceSPM > 0 ? imuCadenceSPM : nil
        session.imuStepCount = imuStepCount > 0 ? imuStepCount : nil
        if let imuSway = balanceAnalyzer.imuSwayMetrics {
            session.imuSwayRmsML = imuSway.rmsAccelerationML
            session.imuSwayRmsAP = imuSway.rmsAccelerationAP
            session.imuSwayJerkRMS = imuSway.jerkRMS
            session.dominantSwayFrequencyHz = imuSway.dominantSwayFrequencyHz
        }

        // Trunk motion (gyroscope-derived)
        let trunkMotion = trunkMotionAnalyzer.analyze()
        session.trunkPeakRotationVelocityDPS = trunkMotion.peakRotationVelocityDPS
        session.trunkAvgRotationRangeDeg = trunkMotion.averageRotationRangeDeg
        session.turnCount = trunkMotion.turnCount
        session.trunkRotationAsymmetryPercent = trunkMotion.rotationAsymmetryPercent
        session.trunkLateralFlexionAvgDeg = trunkMotion.averageLateralFlexionDeg
        session.movementRegularityIndex = trunkMotion.movementRegularityIndex

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
        do {
            session.painRiskAlertsData = try JSONEncoder().encode(painRisk.alerts)
        } catch {
            AppLogger.persistence.error("Failed to encode pain risk alerts: \(error.localizedDescription)")
        }

        context.insert(session)
        do {
            try context.save()
        } catch {
            AppLogger.persistence.error("Failed to save session: \(error.localizedDescription)")
            self.errorMessage = String(localized: "Your session could not be saved. Please try again.")
        }

        // HealthKit auto-save
        if UserDefaults.standard.bool(forKey: "healthKitSync") {
            let hkService = healthKitService
            let steps = session.totalSteps ?? 0
            let speed = session.averageWalkingSpeedMPS
            let stride = session.averageStrideLengthM
            let asymmetry = session.gaitAsymmetryPercent.map { $0 / 100.0 }
            let distance = session.totalDistanceM   // Now tracked from sensors
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
        imuStepDetector.reset()
        trunkMotionAnalyzer.reset()
        resetMetrics()

        return session
    }

    // MARK: - Private

    private func setupCallbacks() {
        // CoreMotion → smoothness, IMU steps, trunk motion, balance IMU
        motionService.onMotionUpdate = { [weak self] frame in
            guard let self else { return }
            self.recorder.recordMotionFrame(frame)

            // Feed accelerometer to smoothness analyzer
            self.smoothnessAnalyzer.recordSample(
                timestamp: frame.timestamp,
                accelerationAP: frame.userAccelerationZ,
                accelerationML: frame.userAccelerationX,
                accelerationV: frame.userAccelerationY
            )

            // IMU step detection (validates ARKit steps + independent cadence)
            if let imuStep = self.imuStepDetector.processSample(
                timestamp: frame.timestamp,
                userAccelerationY: frame.userAccelerationY,
                userAccelerationX: frame.userAccelerationX,
                userAccelerationZ: frame.userAccelerationZ
            ) {
                self.imuCadenceSPM = imuStep.instantCadenceSPM
                self.imuStepCount = self.imuStepDetector.stepCount
            }

            // Trunk motion analysis (gyroscope + attitude)
            self.trunkMotionAnalyzer.processFrame(frame)

            // IMU-based balance sway (60 Hz, higher resolution than ARKit)
            self.balanceAnalyzer.processIMUFrame(
                timestamp: frame.timestamp,
                userAccelerationX: frame.userAccelerationX,
                userAccelerationY: frame.userAccelerationY,
                userAccelerationZ: frame.userAccelerationZ
            )
            if let imuSway = self.balanceAnalyzer.imuSwayMetrics {
                self.imuSwayRmsML = imuSway.rmsAccelerationML
                self.imuSwayRmsAP = imuSway.rmsAccelerationAP
            }
        }

        // CMPedometer → distance + step count + cadence
        pedometerService.onPedometerUpdate = { [weak self] snapshot in
            guard let self else { return }
            self.pedometerDistanceM = snapshot.distanceM ?? 0
            self.pedometerStepCount = snapshot.stepCount
            if let cadence = snapshot.currentCadenceSPM {
                self.pedometerCadenceSPM = cadence
            }
            // Update total distance (pedometer is most accurate source)
            self.updateTotalDistance()
        }
    }

    /// Compute best available distance from all sources.
    private func updateTotalDistance() {
        // Priority: pedometer > ARKit displacement > step estimate
        if pedometerDistanceM > 0 {
            totalDistanceM = pedometerDistanceM
        } else if accumulatedARKitDistanceM > 0 {
            totalDistanceM = accumulatedARKitDistanceM
        } else if stepCount > 0 && avgStrideLengthM > 0 {
            // Fallback: step count × average stride / 2 (stride = 2 steps)
            totalDistanceM = Double(stepCount) * avgStrideLengthM / 2.0
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
                pedometerService.startLiveUpdates()
            }
            return
        }

        guard recordingState == .recording else { return }
        frameIndex += 1

        // ── Distance accumulation from ARKit root displacement ──
        if let root = joints[.root] {
            if let lastPos = lastRootPosition {
                let dx = root.x - lastPos.x
                let dz = root.z - lastPos.z
                let dist = sqrt(dx * dx + dz * dz)
                // Filter out noise (<5cm) and teleports (>2m)
                if dist > 0.05 && dist < 2.0 {
                    accumulatedARKitDistanceM += Double(dist)
                }
            }
            lastRootPosition = root
            updateTotalDistance()
        }

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

        // ── Record detected step (with IMU cross-validation) ──
        if let strike = gaitMetrics.stepDetected {
            // Cross-validate ARKit step with IMU accelerometer peak
            let imuConfidence = imuStepDetector.validateARKitStep(at: strike.timestamp)

            var stepEvent = StepEvent(
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
            // Only record steps with reasonable IMU confidence (filter false positives)
            // Threshold of 0.2 is lenient — purely supplementary validation
            if imuConfidence >= 0.2 {
                recorder.recordStep(stepEvent)
                stepCount = recorder.stepCount
            } else {
                // Still record but log for analysis quality tracking
                recorder.recordStep(stepEvent)
                stepCount = recorder.stepCount
                AppLogger.analysis.debug("Low IMU confidence (\(String(format: "%.2f", imuConfidence))) for ARKit step at \(String(format: "%.2f", strike.timestamp))s")
            }

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

        // Sensor-derived metrics
        imuCadenceSPM = 0
        imuStepCount = 0
        imuSwayRmsML = 0
        imuSwayRmsAP = 0
        pedometerDistanceM = 0
        pedometerStepCount = 0
        pedometerCadenceSPM = 0
        totalDistanceM = 0
        trunkRotationVelocityDPS = 0
        turnCount = 0
        lastRootPosition = nil
        accumulatedARKitDistanceM = 0
    }
}
