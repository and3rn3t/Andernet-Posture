//
//  DashboardViewModel.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import Foundation
import SwiftData
import Observation

/// Data point for trend charts on the dashboard.
struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// Drives the DashboardView — aggregates session history into displayable summaries.
@Observable
final class DashboardViewModel {

    // MARK: - Aggregated metrics

    var recentPostureScore: Double?
    var recentCadence: Double?
    var recentStrideLength: Double?
    var totalSessions: Int = 0
    var totalWalkingTime: TimeInterval = 0

    // Trend data for Swift Charts
    var postureScoreTrend: [TrendPoint] = []
    var cadenceTrend: [TrendPoint] = []
    var strideLengthTrend: [TrendPoint] = []

    // Quick posture summary
    var postureLabel: String {
        guard let score = recentPostureScore else { return "No data" }
        switch score {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs Improvement"
        }
    }

    var formattedTotalTime: String {
        let minutes = Int(totalWalkingTime) / 60
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        return "\(hours)h \(remaining)m"
    }

    // MARK: - Refresh

    /// Recompute dashboard from the given sessions (call on appear or after capture).
    func refresh(sessions: [GaitSession]) {
        totalSessions = sessions.count

        guard !sessions.isEmpty else {
            recentPostureScore = nil
            recentCadence = nil
            recentStrideLength = nil
            totalWalkingTime = 0
            postureScoreTrend = []
            cadenceTrend = []
            strideLengthTrend = []
            return
        }

        // Most recent values
        let sorted = sessions.sorted { $0.date > $1.date }
        recentPostureScore = sorted.first?.postureScore
        recentCadence = sorted.first?.averageCadenceSPM
        recentStrideLength = sorted.first?.averageStrideLengthM

        totalWalkingTime = sessions.reduce(0) { $0 + $1.duration }

        // Trends (last 30 sessions, oldest first)
        let trendSessions = Array(sorted.prefix(30).reversed())

        postureScoreTrend = trendSessions.compactMap { s in
            guard let score = s.postureScore else { return nil }
            return TrendPoint(date: s.date, value: score)
        }

        cadenceTrend = trendSessions.compactMap { s in
            guard let cadence = s.averageCadenceSPM else { return nil }
            return TrendPoint(date: s.date, value: cadence)
        }

        strideLengthTrend = trendSessions.compactMap { s in
            guard let stride = s.averageStrideLengthM else { return nil }
            return TrendPoint(date: s.date, value: stride)
        }
    }
}
