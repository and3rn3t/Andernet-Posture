//
//  DashboardView.swift
//  Andernet Posture
//
//  iOS 26 HIG: Large title, Liquid Glass cards, Swift Charts with Audio Graphs,
//  scroll edge effects, grouped sections.
//

import SwiftUI
import SwiftData
import Charts
import Accessibility

struct DashboardView: View {
    @Query(sort: \GaitSession.date, order: .reverse) private var sessions: [GaitSession]
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Quick Stats Cards
                    quickStatsSection

                    // MARK: - Clinical Quick Glance
                    if viewModel.totalSessions > 0 {
                        clinicalQuickGlance
                    }

                    // MARK: - Insights
                    if !viewModel.insights.isEmpty {
                        insightsSection
                    }

                    // MARK: - Goals
                    NavigationLink(destination: GoalsView()) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundStyle(.blue)
                            Text("Goals & Progress")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    // MARK: - Posture Score Trend
                    if !viewModel.postureScoreTrend.isEmpty {
                        trendChart(
                            title: "Posture Score",
                            data: viewModel.postureScoreTrend,
                            color: .blue,
                            unit: ""
                        )
                    }

                    // MARK: - Walking Speed Trend
                    if !viewModel.walkingSpeedTrend.isEmpty {
                        trendChart(
                            title: "Walking Speed",
                            data: viewModel.walkingSpeedTrend,
                            color: .teal,
                            unit: "m/s"
                        )
                    }

                    // MARK: - Cadence Trend
                    if !viewModel.cadenceTrend.isEmpty {
                        trendChart(
                            title: "Cadence",
                            data: viewModel.cadenceTrend,
                            color: .green,
                            unit: "SPM"
                        )
                    }

                    // MARK: - CVA Trend
                    if !viewModel.cvaTrend.isEmpty {
                        trendChart(
                            title: "Craniovertebral Angle",
                            data: viewModel.cvaTrend,
                            color: .purple,
                            unit: "°"
                        )
                    }

                    // MARK: - Fall Risk Trend
                    if !viewModel.fallRiskTrend.isEmpty {
                        trendChart(
                            title: "Fall Risk Score",
                            data: viewModel.fallRiskTrend,
                            color: .red,
                            unit: ""
                        )
                    }

                    // MARK: - Stride Length Trend
                    if !viewModel.strideLengthTrend.isEmpty {
                        trendChart(
                            title: "Stride Length",
                            data: viewModel.strideLengthTrend,
                            color: .orange,
                            unit: "m"
                        )
                    }

                    // MARK: - Empty state
                    if sessions.isEmpty {
                        ContentUnavailableView(
                            "No Sessions Yet",
                            systemImage: "figure.walk",
                            description: Text("Start a capture session to see your posture and gait analytics.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .onAppear {
                viewModel.refresh(sessions: sessions)
            }
            .onChange(of: sessions.count) {
                viewModel.refresh(sessions: sessions)
            }
        }
    }

    // MARK: - Quick Stats

    @ViewBuilder
    private var quickStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "Posture",
                value: viewModel.postureLabel,
                score: viewModel.recentPostureScore,
                icon: "figure.stand"
            )

            StatCard(
                title: "Walking Speed",
                value: viewModel.walkingSpeedLabel,
                severity: viewModel.recentWalkingSpeed.map { GaitThresholds.speedSeverity($0) },
                icon: "speedometer"
            )

            StatCard(
                title: "Cadence",
                value: viewModel.recentCadence.map { String(format: "%.0f SPM", $0) } ?? "—",
                icon: "metronome.fill"
            )

            StatCard(
                title: "Stride",
                value: viewModel.recentStrideLength.map { String(format: "%.2f m", $0) } ?? "—",
                icon: "ruler.fill"
            )

            StatCard(
                title: "Fall Risk",
                value: viewModel.fallRiskLabel,
                severity: fallRiskSeverity,
                icon: "exclamationmark.triangle.fill"
            )

            StatCard(
                title: "Sessions",
                value: "\(viewModel.totalSessions)",
                subtitle: viewModel.formattedTotalTime,
                icon: "clock.fill"
            )
        }
    }

    // MARK: - Clinical Quick Glance

    @ViewBuilder
    private var clinicalQuickGlance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clinical Insights")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                if let cva = viewModel.recentCVA {
                    ClinicalMiniCard(
                        label: "CVA",
                        value: String(format: "%.0f°", cva),
                        severity: PostureThresholds.cvaSeverity(cva)
                    )
                }

                if let sym = viewModel.recentGaitSymmetry {
                    ClinicalMiniCard(
                        label: "Symmetry",
                        value: String(format: "%.0f%%", sym),
                        severity: GaitThresholds.symmetrySeverity(sym)
                    )
                }

                if let reba = viewModel.recentRebaScore {
                    ClinicalMiniCard(
                        label: "REBA",
                        value: "\(reba)",
                        severity: rebaSeverity(reba)
                    )
                }

                if let fatigue = viewModel.recentFatigueIndex {
                    ClinicalMiniCard(
                        label: "Fatigue",
                        value: String(format: "%.0f", fatigue),
                        severity: fatigueSeverity(fatigue)
                    )
                }

                if let kendall = viewModel.recentKendallType {
                    ClinicalMiniCard(
                        label: "Posture Type",
                        value: kendallDisplayName(kendall),
                        severity: kendall == "ideal" ? .normal : .mild
                    )
                }

                if let pattern = viewModel.recentGaitPattern {
                    ClinicalMiniCard(
                        label: "Gait Pattern",
                        value: patternDisplayName(pattern),
                        severity: pattern == "normal" ? .normal : .mild
                    )
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Trend Chart

    @ViewBuilder
    private func trendChart(title: String, data: [TrendPoint], color: Color, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(title, point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.gradient)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value(title, point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.opacity(0.1).gradient)
            }
            .chartYAxisLabel(unit)
            .frame(height: 180)
            .accessibilityChartDescriptor(TrendChartDescriptor(title: title, data: data, unit: unit))
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private var fallRiskSeverity: ClinicalSeverity? {
        guard let level = viewModel.recentFallRiskLevel else { return nil }
        switch level {
        case "low": return .normal
        case "moderate": return .moderate
        case "high": return .severe
        default: return nil
        }
    }

    private func rebaSeverity(_ score: Int) -> ClinicalSeverity {
        switch score {
        case 1: return .normal
        case 2...3: return .mild
        case 4...7: return .moderate
        default: return .severe
        }
    }

    private func fatigueSeverity(_ index: Double) -> ClinicalSeverity {
        if index < 25 { return .normal }
        if index < 50 { return .mild }
        if index < 75 { return .moderate }
        return .severe
    }

    private func kendallDisplayName(_ raw: String) -> String {
        switch raw {
        case "ideal": return "Ideal"
        case "kyphosisLordosis": return "Kypho-Lord"
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
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    var score: Double? = nil
    var severity: ClinicalSeverity? = nil
    var subtitle: String? = nil
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Spacer()
                if let score {
                    scoreIndicator(score)
                } else if let severity {
                    Circle()
                        .fill(severityColor(severity))
                        .frame(width: 10, height: 10)
                }
            }

            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let subtitle {
                    Spacer()
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func scoreIndicator(_ score: Double) -> some View {
        Circle()
            .fill(scoreColor(score))
            .frame(width: 10, height: 10)
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private func severityColor(_ severity: ClinicalSeverity) -> Color {
        switch severity {
        case .normal: return .green
        case .mild: return .yellow
        case .moderate: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Clinical Mini Card

private struct ClinicalMiniCard: View {
    let label: String
    let value: String
    let severity: ClinicalSeverity

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.callout, design: .rounded).bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(severityColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(severityColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var severityColor: Color {
        switch severity {
        case .normal: return .green
        case .mild: return .yellow
        case .moderate: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Insights Section

extension DashboardView {
    @ViewBuilder
    var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Insights")
                    .font(.headline)
                Spacer()
                if viewModel.insights.count > 5 {
                    NavigationLink("See All") {
                        List(viewModel.insights) { insight in
                            insightCard(insight)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .navigationTitle("All Insights")
                    }
                    .font(.subheadline)
                }
            }

            ForEach(viewModel.insights.prefix(5)) { insight in
                insightCard(insight)
            }
        }
    }

    @ViewBuilder
    private func insightCard(_ insight: Insight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title3)
                .foregroundStyle(insightSeverityColor(insight.severity))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.bold())
                Text(insight.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(insightSeverityColor(insight.severity).opacity(0.3), lineWidth: 1)
        )
    }

    private func insightSeverityColor(_ severity: ClinicalSeverity) -> Color {
        switch severity {
        case .normal: return .green
        case .mild: return .yellow
        case .moderate: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Audio Graph Descriptor (Accessibility)

private struct TrendChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let data: [TrendPoint]
    let unit: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Date",
            range: 0...Double(max(1, data.count - 1)),
            gridlinePositions: []
        ) { idx in
            let i = Int(idx)
            guard i >= 0 && i < data.count else { return "" }
            return data[i].date.formatted(date: .abbreviated, time: .omitted)
        }

        let values = data.map(\.value)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100

        let yAxis = AXNumericDataAxisDescriptor(
            title: title,
            range: minVal...maxVal,
            gridlinePositions: []
        ) { val in
            String(format: "%.1f \(unit)", val)
        }

        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: true,
            dataPoints: data.enumerated().map { i, point in
                AXDataPoint(x: Double(i), y: point.value)
            }
        )

        return AXChartDescriptor(
            title: "\(title) Trend",
            summary: "Shows \(title.lowercased()) over your last \(data.count) sessions.",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: GaitSession.self, inMemory: true)
}
