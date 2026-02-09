//
//  SessionDetailViewModel.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import Foundation
import Observation

/// Data point for time-series charts within a session detail view.
struct TimeSeriesPoint: Identifiable {
    let id = UUID()
    let time: Double   // seconds since session start
    let value: Double
}

/// Per-foot step aggregation for the detail view.
struct FootStats {
    let avgStride: Double
    let count: Int
}

/// A labeled clinical metric with optional severity for display.
struct ClinicalMetricItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var severity: ClinicalSeverity?
    var detail: String?
}

/// Drives SessionDetailView — decodes and presents time-series data for one session.
@Observable
final class SessionDetailViewModel {

    let session: GaitSession

    // Decoded time-series
    var trunkLeanSeries: [TimeSeriesPoint] = []
    var lateralLeanSeries: [TimeSeriesPoint] = []
    var cadenceSeries: [TimeSeriesPoint] = []
    var strideSeries: [TimeSeriesPoint] = []
    var cvaSeries: [TimeSeriesPoint] = []
    var walkingSpeedSeries: [TimeSeriesPoint] = []
    var swayVelocitySeries: [TimeSeriesPoint] = []
    var rebaSeries: [TimeSeriesPoint] = []
    var hipFlexionLeftSeries: [TimeSeriesPoint] = []
    var hipFlexionRightSeries: [TimeSeriesPoint] = []
    var kneeFlexionLeftSeries: [TimeSeriesPoint] = []
    var kneeFlexionRightSeries: [TimeSeriesPoint] = []

    // Step analysis
    var leftFootStats: FootStats?
    var rightFootStats: FootStats?
    var symmetryRatio: Double?

    // Summary strings
    var summaryItems: [(label: String, value: String)] = []

    // Clinical sections
    var postureMetrics: [ClinicalMetricItem] = []
    var gaitMetrics: [ClinicalMetricItem] = []
    var romMetrics: [ClinicalMetricItem] = []
    var balanceMetrics: [ClinicalMetricItem] = []
    var riskMetrics: [ClinicalMetricItem] = []
    var clinicalTestMetrics: [ClinicalMetricItem] = []
    var painAlerts: [PainRiskAlert] = []

    init(session: GaitSession) {
        self.session = session
        decode()
    }

    // MARK: - Decode & Compute

    private func decode() {
        let frames = session.decodedFrames
        let steps = session.decodedStepEvents

        guard !frames.isEmpty else {
            buildSummary()
            buildClinicalSections()
            return
        }
        let startTime = frames.first!.timestamp

        // Down-sample to ~2 pts/sec for chart performance
        let targetInterval = 0.5
        var lastPlotted = -targetInterval

        for f in frames {
            let t = f.timestamp - startTime
            guard t - lastPlotted >= targetInterval else { continue }
            lastPlotted = t

            trunkLeanSeries.append(TimeSeriesPoint(time: t, value: f.trunkLeanDeg))
            lateralLeanSeries.append(TimeSeriesPoint(time: t, value: f.lateralLeanDeg))
            cadenceSeries.append(TimeSeriesPoint(time: t, value: f.cadenceSPM))
            strideSeries.append(TimeSeriesPoint(time: t, value: f.avgStrideLengthM))
            cvaSeries.append(TimeSeriesPoint(time: t, value: f.craniovertebralAngleDeg))

            if f.walkingSpeedMPS > 0 {
                walkingSpeedSeries.append(TimeSeriesPoint(time: t, value: f.walkingSpeedMPS))
            }
            if f.swayVelocityMMS > 0 {
                swayVelocitySeries.append(TimeSeriesPoint(time: t, value: f.swayVelocityMMS))
            }
            if let reba = f.rebaScore {
                rebaSeries.append(TimeSeriesPoint(time: t, value: Double(reba)))
            }

            hipFlexionLeftSeries.append(TimeSeriesPoint(time: t, value: f.hipFlexionLeftDeg))
            hipFlexionRightSeries.append(TimeSeriesPoint(time: t, value: f.hipFlexionRightDeg))
            kneeFlexionLeftSeries.append(TimeSeriesPoint(time: t, value: f.kneeFlexionLeftDeg))
            kneeFlexionRightSeries.append(TimeSeriesPoint(time: t, value: f.kneeFlexionRightDeg))
        }

        // Step analysis
        let leftSteps = steps.filter { $0.foot == .left }
        let rightSteps = steps.filter { $0.foot == .right }

        let leftStrides = leftSteps.compactMap(\.strideLengthM)
        let rightStrides = rightSteps.compactMap(\.strideLengthM)

        if !leftStrides.isEmpty {
            leftFootStats = FootStats(
                avgStride: leftStrides.reduce(0, +) / Double(leftStrides.count),
                count: leftSteps.count
            )
        }
        if !rightStrides.isEmpty {
            rightFootStats = FootStats(
                avgStride: rightStrides.reduce(0, +) / Double(rightStrides.count),
                count: rightSteps.count
            )
        }

        if let l = leftFootStats?.avgStride, let r = rightFootStats?.avgStride, l > 0, r > 0 {
            symmetryRatio = min(l, r) / max(l, r)
        }

        // Decode pain risk alerts
        if let data = session.painRiskAlertsData {
            painAlerts = (try? JSONDecoder().decode([PainRiskAlert].self, from: data)) ?? []
        }

        buildSummary()
        buildClinicalSections()
    }

    private func buildSummary() {
        summaryItems = []
        summaryItems.append(("Duration", session.formattedDuration))

        if let score = session.postureScore {
            summaryItems.append(("Posture Score", String(format: "%.0f", score)))
        }
        if let speed = session.averageWalkingSpeedMPS, speed > 0 {
            summaryItems.append(("Walking Speed", String(format: "%.2f m/s", speed)))
        }
        if let cadence = session.averageCadenceSPM {
            summaryItems.append(("Avg Cadence", String(format: "%.0f SPM", cadence)))
        }
        if let stride = session.averageStrideLengthM {
            summaryItems.append(("Avg Stride", String(format: "%.2f m", stride)))
        }
        if let steps = session.totalSteps {
            summaryItems.append(("Total Steps", "\(steps)"))
        }
        if let risk = session.fallRiskLevel {
            summaryItems.append(("Fall Risk", risk.capitalized))
        }
    }

    // MARK: - Clinical Sections

    private func buildClinicalSections() {
        buildPostureSection()
        buildGaitSection()
        buildROMSection()
        buildBalanceSection()
        buildRiskSection()
        buildClinicalTestSection()
    }

    private func buildPostureSection() {
        postureMetrics = []

        if let cva = session.averageCVADeg {
            postureMetrics.append(ClinicalMetricItem(
                label: "Craniovertebral Angle",
                value: String(format: "%.1f°", cva),
                severity: PostureThresholds.cvaSeverity(cva),
                detail: "Forward head posture indicator (normal: 49–56°)"
            ))
        }
        if let sva = session.averageSVACm {
            postureMetrics.append(ClinicalMetricItem(
                label: "Sagittal Vertical Axis",
                value: String(format: "%.1f cm", sva),
                severity: PostureThresholds.svaSeverity(sva),
                detail: "Forward trunk displacement (normal: <5 cm)"
            ))
        }
        if let trunk = session.averageTrunkLeanDeg {
            postureMetrics.append(ClinicalMetricItem(
                label: "Trunk Forward Lean",
                value: String(format: "%.1f°", trunk),
                severity: PostureThresholds.trunkForwardSeverity(trunk)
            ))
        }
        if let lateral = session.averageLateralLeanDeg {
            postureMetrics.append(ClinicalMetricItem(
                label: "Lateral Lean",
                value: String(format: "%.1f°", lateral),
                severity: PostureThresholds.lateralLeanSeverity(lateral)
            ))
        }
        if let kyphosis = session.averageThoracicKyphosisDeg {
            postureMetrics.append(ClinicalMetricItem(
                label: "Thoracic Kyphosis",
                value: String(format: "%.1f°", kyphosis),
                severity: PostureThresholds.kyphosisSeverity(kyphosis),
                detail: "Upper back curvature (normal: 20–45°)"
            ))
        }
        if let lordosis = session.averageLumbarLordosisDeg {
            postureMetrics.append(ClinicalMetricItem(
                label: "Lumbar Lordosis",
                value: String(format: "%.1f°", lordosis),
                severity: PostureThresholds.lordosisSeverity(lordosis),
                detail: "Lower back curvature (normal: 40–60°)"
            ))
        }
        if let shoulder = session.averageShoulderAsymmetryCm {
            postureMetrics.append(ClinicalMetricItem(
                label: "Shoulder Asymmetry",
                value: String(format: "%.1f cm", shoulder),
                severity: PostureThresholds.shoulderSeverity(cm: shoulder)
            ))
        }
        if let pelvic = session.averagePelvicObliquityDeg {
            postureMetrics.append(ClinicalMetricItem(
                label: "Pelvic Obliquity",
                value: String(format: "%.1f°", pelvic),
                severity: PostureThresholds.pelvicSeverity(pelvic)
            ))
        }
        if let coronal = session.averageCoronalDeviationCm {
            postureMetrics.append(ClinicalMetricItem(
                label: "Coronal Spine Deviation",
                value: String(format: "%.1f cm", coronal),
                severity: PostureThresholds.scoliosisSeverity(cm: coronal)
            ))
        }
        if let kendall = session.kendallPosturalType {
            postureMetrics.append(ClinicalMetricItem(
                label: "Postural Type (Kendall)",
                value: kendallDisplayName(kendall),
                severity: kendall == "ideal" ? .normal : .mild
            ))
        }
        if let nypr = session.nyprScore {
            let max = NYPRItem.maxAutomatableScore
            postureMetrics.append(ClinicalMetricItem(
                label: "NYPR Score",
                value: "\(nypr)/\(max)",
                severity: nyprSeverity(nypr, max: max),
                detail: "New York Posture Rating (9 automated items)"
            ))
        }
    }

    private func buildGaitSection() {
        gaitMetrics = []

        if let speed = session.averageWalkingSpeedMPS, speed > 0 {
            gaitMetrics.append(ClinicalMetricItem(
                label: "Walking Speed",
                value: String(format: "%.2f m/s", speed),
                severity: GaitThresholds.speedSeverity(speed),
                detail: "The \"6th vital sign\" (normal: ≥1.0 m/s)"
            ))
        }
        if let cadence = session.averageCadenceSPM {
            gaitMetrics.append(ClinicalMetricItem(
                label: "Cadence",
                value: String(format: "%.0f SPM", cadence),
                severity: GaitThresholds.cadenceNormal.contains(cadence) ? .normal : .mild
            ))
        }
        if let stride = session.averageStrideLengthM {
            gaitMetrics.append(ClinicalMetricItem(
                label: "Stride Length",
                value: String(format: "%.2f m", stride)
            ))
        }
        if let sym = session.gaitAsymmetryPercent {
            gaitMetrics.append(ClinicalMetricItem(
                label: "Gait Asymmetry (Robinson SI)",
                value: String(format: "%.1f%%", sym),
                severity: GaitThresholds.symmetrySeverity(sym),
                detail: "Bilateral step symmetry (normal: <10%)"
            ))
        }
        if let stepWidth = session.averageStepWidthCm {
            gaitMetrics.append(ClinicalMetricItem(
                label: "Step Width",
                value: String(format: "%.1f cm", stepWidth),
                severity: GaitThresholds.stepWidthNormal.contains(stepWidth) ? .normal : .mild
            ))
        }
        if let pattern = session.gaitPatternClassification {
            gaitMetrics.append(ClinicalMetricItem(
                label: "Gait Pattern",
                value: patternDisplayName(pattern),
                severity: pattern == "normal" ? .normal : .mild
            ))
        }
        if let walkRatio = session.walkRatio {
            gaitMetrics.append(ClinicalMetricItem(
                label: "Walk Ratio",
                value: String(format: "%.4f", walkRatio),
                detail: "Step length / cadence (normal: ~0.0064)"
            ))
        }
        if let met = session.estimatedMET {
            gaitMetrics.append(ClinicalMetricItem(
                label: "Estimated MET",
                value: String(format: "%.1f", met),
                detail: "Metabolic equivalent of task"
            ))
        }
    }

    private func buildROMSection() {
        romMetrics = []

        if let hipROM = session.averageHipROMDeg {
            romMetrics.append(ClinicalMetricItem(
                label: "Hip ROM (avg bilateral)",
                value: String(format: "%.1f°", hipROM),
                severity: GaitROMLimits.hipFlexionNormal.contains(hipROM) ? .normal : .mild,
                detail: "Sagittal hip flexion (normal gait: 30–40°)"
            ))
        }
        if let kneeROM = session.averageKneeROMDeg {
            romMetrics.append(ClinicalMetricItem(
                label: "Knee ROM (avg bilateral)",
                value: String(format: "%.1f°", kneeROM),
                severity: GaitROMLimits.kneeFlexionSwingNormal.contains(kneeROM) ? .normal : .mild,
                detail: "Knee flexion in swing (normal: 60–70°)"
            ))
        }
        if let trunkRot = session.trunkRotationRangeDeg {
            romMetrics.append(ClinicalMetricItem(
                label: "Trunk Rotation Range",
                value: String(format: "%.1f°", trunkRot),
                severity: GaitROMLimits.trunkRotationTotalArc.contains(trunkRot) ? .normal : .mild,
                detail: "Total transverse arc (normal: 10–16°)"
            ))
        }
        if let armAsym = session.armSwingAsymmetryPercent {
            romMetrics.append(ClinicalMetricItem(
                label: "Arm Swing Asymmetry",
                value: String(format: "%.1f%%", armAsym),
                severity: armAsym <= GaitThresholds.armSwingAsymmetryNormalMax ? .normal : .mild,
                detail: "Bilateral arm swing difference (normal: <10%)"
            ))
        }
    }

    private func buildBalanceSection() {
        balanceMetrics = []

        if let sway = session.averageSwayVelocityMMS {
            balanceMetrics.append(ClinicalMetricItem(
                label: "Sway Velocity",
                value: String(format: "%.1f mm/s", sway),
                severity: sway <= BalanceThresholds.swayVelocityFallRisk ? .normal : .severe,
                detail: "CoM proxy velocity (fall risk: >25 mm/s)"
            ))
        }
        if let area = session.swayAreaCm2 {
            balanceMetrics.append(ClinicalMetricItem(
                label: "Sway Area (95% ellipse)",
                value: String(format: "%.2f cm²", area),
                severity: area <= BalanceThresholds.swayAreaFallRisk ? .normal : .severe
            ))
        }
        if let romberg = session.rombergRatio {
            balanceMetrics.append(ClinicalMetricItem(
                label: "Romberg Ratio",
                value: String(format: "%.2f", romberg),
                severity: romberg <= BalanceThresholds.rombergRatioNormalMax ? .normal : .moderate,
                detail: "Eyes closed / eyes open sway (normal: <2.0)"
            ))
        }
    }

    private func buildRiskSection() {
        riskMetrics = []

        if let fallRisk = session.fallRiskScore {
            let level = session.fallRiskLevel ?? "unknown"
            riskMetrics.append(ClinicalMetricItem(
                label: "Fall Risk Score",
                value: String(format: "%.0f/100", fallRisk),
                severity: fallRiskSeverity(level),
                detail: "Composite 8-factor weighted assessment"
            ))
        }
        if let fatigue = session.fatigueIndex {
            riskMetrics.append(ClinicalMetricItem(
                label: "Fatigue Index",
                value: String(format: "%.0f/100", fatigue),
                severity: fatigueSeverity(fatigue),
                detail: "Posture/gait degradation over session"
            ))
        }
        if let reba = session.rebaScore {
            riskMetrics.append(ClinicalMetricItem(
                label: "REBA Score",
                value: "\(reba)/15",
                severity: rebaSeverity(reba),
                detail: rebaActionLabel(reba)
            ))
        }
        if let sparc = session.sparcScore {
            riskMetrics.append(ClinicalMetricItem(
                label: "Smoothness (SPARC)",
                value: String(format: "%.2f", sparc),
                severity: sparc > -2.0 ? .normal : sparc > -3.0 ? .mild : .moderate,
                detail: "Movement smoothness (closer to 0 = smoother)"
            ))
        }
        if let hr = session.harmonicRatio {
            riskMetrics.append(ClinicalMetricItem(
                label: "Harmonic Ratio (AP)",
                value: String(format: "%.2f", hr),
                severity: hr > 2.0 ? .normal : hr > 1.5 ? .mild : .moderate,
                detail: "Gait rhythmicity (higher = more regular)"
            ))
        }
        if let upperCrossed = session.upperCrossedScore {
            riskMetrics.append(ClinicalMetricItem(
                label: "Upper Crossed Syndrome",
                value: String(format: "%.0f/100", upperCrossed),
                severity: upperCrossed < 40 ? .normal : upperCrossed < 60 ? .mild : .moderate,
                detail: "Janda's upper crossed pattern"
            ))
        }
        if let lowerCrossed = session.lowerCrossedScore {
            riskMetrics.append(ClinicalMetricItem(
                label: "Lower Crossed Syndrome",
                value: String(format: "%.0f/100", lowerCrossed),
                severity: lowerCrossed < 40 ? .normal : lowerCrossed < 60 ? .mild : .moderate,
                detail: "Janda's lower crossed pattern"
            ))
        }
        if let frailty = session.frailtyScore {
            riskMetrics.append(ClinicalMetricItem(
                label: "Frailty (Fried)",
                value: "\(frailty)/5",
                severity: frailty == 0 ? .normal : frailty <= 2 ? .mild : .severe,
                detail: frailty == 0 ? "Robust" : frailty <= 2 ? "Pre-frail" : "Frail"
            ))
        }
    }

    private func buildClinicalTestSection() {
        clinicalTestMetrics = []

        if let tug = session.tugTimeSec {
            clinicalTestMetrics.append(ClinicalMetricItem(
                label: "Timed Up & Go",
                value: String(format: "%.1f sec", tug),
                severity: tug <= 10 ? .normal : tug <= GaitThresholds.tugFallRisk ? .mild : .severe,
                detail: "Fall risk threshold: >13.5 sec"
            ))
        }
        if let sixMW = session.sixMinuteWalkDistanceM {
            clinicalTestMetrics.append(ClinicalMetricItem(
                label: "6-Minute Walk",
                value: String(format: "%.0f m", sixMW),
                detail: "Functional exercise capacity"
            ))
        }
    }

    // MARK: - Helpers

    private func kendallDisplayName(_ raw: String) -> String {
        switch raw {
        case "ideal": return "Ideal"
        case "kyphosisLordosis": return "Kyphosis-Lordosis"
        case "flatBack": return "Flat Back"
        case "swayBack": return "Sway Back"
        default: return raw.capitalized
        }
    }

    private func patternDisplayName(_ raw: String) -> String {
        switch raw {
        case "normal": return "Normal"
        case "antalgic": return "Antalgic"
        case "trendelenburg": return "Trendelenburg"
        case "festinating": return "Festinating"
        case "circumduction": return "Circumduction"
        case "ataxic": return "Ataxic"
        case "waddling": return "Waddling"
        default: return raw.capitalized
        }
    }

    private func nyprSeverity(_ score: Int, max: Int) -> ClinicalSeverity {
        let pct = Double(score) / Double(max) * 100
        if pct >= 80 { return .normal }
        if pct >= 60 { return .mild }
        if pct >= 40 { return .moderate }
        return .severe
    }

    private func fallRiskSeverity(_ level: String) -> ClinicalSeverity {
        switch level {
        case "low": return .normal
        case "moderate": return .moderate
        case "high": return .severe
        default: return .normal
        }
    }

    private func fatigueSeverity(_ index: Double) -> ClinicalSeverity {
        if index < 25 { return .normal }
        if index < 50 { return .mild }
        if index < 75 { return .moderate }
        return .severe
    }

    private func rebaSeverity(_ score: Int) -> ClinicalSeverity {
        switch score {
        case 1: return .normal
        case 2...3: return .mild
        case 4...7: return .moderate
        default: return .severe
        }
    }

    private func rebaActionLabel(_ score: Int) -> String {
        switch score {
        case 1: return "Negligible risk — no action needed"
        case 2...3: return "Low risk — change may be needed"
        case 4...7: return "Medium risk — investigation needed"
        case 8...10: return "High risk — implement change soon"
        default: return "Very high risk — immediate change needed"
        }
    }
}
