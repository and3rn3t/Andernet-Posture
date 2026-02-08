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

/// Drives SessionDetailView — decodes and presents time-series data for one session.
@Observable
final class SessionDetailViewModel {

    let session: GaitSession

    // Decoded time-series
    var trunkLeanSeries: [TimeSeriesPoint] = []
    var lateralLeanSeries: [TimeSeriesPoint] = []
    var cadenceSeries: [TimeSeriesPoint] = []
    var strideSeries: [TimeSeriesPoint] = []

    // Step analysis
    var leftFootStats: FootStats?
    var rightFootStats: FootStats?
    var symmetryRatio: Double?

    // Summary strings
    var summaryItems: [(label: String, value: String)] = []

    init(session: GaitSession) {
        self.session = session
        decode()
    }

    // MARK: - Decode & Compute

    private func decode() {
        let frames = session.decodedFrames
        let steps = session.decodedStepEvents

        guard !frames.isEmpty else { return }
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

        // Summary
        buildSummary()
    }

    private func buildSummary() {
        summaryItems = []
        summaryItems.append(("Duration", session.formattedDuration))

        if let score = session.postureScore {
            summaryItems.append(("Posture Score", String(format: "%.0f", score)))
        }
        if let cadence = session.averageCadenceSPM {
            summaryItems.append(("Avg Cadence", String(format: "%.0f SPM", cadence)))
        }
        if let stride = session.averageStrideLengthM {
            summaryItems.append(("Avg Stride", String(format: "%.2f m", stride)))
        }
        if let trunk = session.averageTrunkLeanDeg {
            summaryItems.append(("Avg Trunk Lean", String(format: "%.1f°", trunk)))
        }
        if let peak = session.peakTrunkLeanDeg {
            summaryItems.append(("Peak Trunk Lean", String(format: "%.1f°", peak)))
        }
        if let lateral = session.averageLateralLeanDeg {
            summaryItems.append(("Avg Lateral Lean", String(format: "%.1f°", lateral)))
        }
        if let steps = session.totalSteps {
            summaryItems.append(("Total Steps", "\(steps)"))
        }
        if let sym = symmetryRatio {
            summaryItems.append(("Gait Symmetry", String(format: "%.0f%%", sym * 100)))
        }
    }
}
