//
//  SessionDetailView.swift
//  Andernet Posture
//
//  iOS 26 HIG: Grouped sections, Swift Charts with Audio Graphs, Liquid Glass material.
//  Comprehensive clinical analytics display with severity color coding.
//

import SwiftUI
import Charts
import Accessibility

struct SessionDetailView: View {
    @State private var viewModel: SessionDetailViewModel

    init(session: GaitSession) {
        _viewModel = State(initialValue: SessionDetailViewModel(session: session))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Summary
                summarySection

                // MARK: - Posture Analytics
                if !viewModel.postureMetrics.isEmpty {
                    clinicalSection(title: "Posture Analytics", icon: "figure.stand", items: viewModel.postureMetrics)
                }

                // MARK: - Gait Analytics
                if !viewModel.gaitMetrics.isEmpty {
                    clinicalSection(title: "Gait Analytics", icon: "figure.walk", items: viewModel.gaitMetrics)
                }

                // MARK: - Joint ROM
                if !viewModel.romMetrics.isEmpty {
                    clinicalSection(title: "Range of Motion", icon: "arrow.triangle.2.circlepath", items: viewModel.romMetrics)
                }

                // MARK: - Balance
                if !viewModel.balanceMetrics.isEmpty {
                    clinicalSection(title: "Balance & Sway", icon: "circle.dotted", items: viewModel.balanceMetrics)
                }

                // MARK: - Risk Assessment
                if !viewModel.riskMetrics.isEmpty {
                    clinicalSection(title: "Risk Assessment", icon: "exclamationmark.shield.fill", items: viewModel.riskMetrics)
                }

                // MARK: - Clinical Tests
                if !viewModel.clinicalTestMetrics.isEmpty {
                    clinicalSection(title: "Clinical Tests", icon: "stethoscope", items: viewModel.clinicalTestMetrics)
                }

                // MARK: - Pain Risk Alerts
                if !viewModel.painAlerts.isEmpty {
                    painAlertsSection
                }

                // MARK: - Time Series Charts
                chartsSection

                // MARK: - Step Analysis
                if viewModel.leftFootStats != nil || viewModel.rightFootStats != nil {
                    stepAnalysisSection
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.session.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if viewModel.session.framesData != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SessionPlaybackView(session: viewModel.session)
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .accessibilityLabel("Play back session")
                }
            }
        }
    }

    // MARK: - Summary Section

    @ViewBuilder
    private var summarySection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(viewModel.summaryItems, id: \.label) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(.title3.bold())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Clinical Section

    @ViewBuilder
    private func clinicalSection(title: String, icon: String, items: [ClinicalMetricItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let detail = item.detail {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text(item.value)
                            .font(.subheadline.bold())
                        if let severity = item.severity {
                            Circle()
                                .fill(severityColor(severity))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.vertical, 2)

                if item.id != items.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Pain Risk Alerts

    @ViewBuilder
    private var painAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pain Risk Alerts", systemImage: "bolt.heart.fill")
                .font(.headline)
                .foregroundStyle(.red)

            ForEach(viewModel.painAlerts, id: \.region) { alert in
                HStack(alignment: .top) {
                    Circle()
                        .fill(severityColor(alert.severity))
                        .frame(width: 10, height: 10)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(alert.region.rawValue.capitalized)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(String(format: "%.0f/100", alert.riskScore))
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(severityColor(alert.severity).opacity(0.2), in: Capsule())
                        }

                        if !alert.factors.isEmpty {
                            Text(alert.factors.joined(separator: " • "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(alert.recommendation)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .italic()
                    }
                }
                .padding(.vertical, 4)

                if alert.region != viewModel.painAlerts.last?.region {
                    Divider()
                }
            }
        }
        .padding()
        .background(.red.opacity(0.05))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Charts Section

    @ViewBuilder
    private var chartsSection: some View {
        // CVA over time
        if !viewModel.cvaSeries.isEmpty {
            timeSeriesChart(title: "Craniovertebral Angle", data: viewModel.cvaSeries, color: .purple, unit: "°")
        }

        // Trunk lean
        if !viewModel.trunkLeanSeries.isEmpty {
            timeSeriesChart(title: "Trunk Lean", data: viewModel.trunkLeanSeries, color: .blue, unit: "°")
        }

        // Lateral lean
        if !viewModel.lateralLeanSeries.isEmpty {
            timeSeriesChart(title: "Lateral Lean", data: viewModel.lateralLeanSeries, color: .purple, unit: "°")
        }

        // Walking speed
        if !viewModel.walkingSpeedSeries.isEmpty {
            timeSeriesChart(title: "Walking Speed", data: viewModel.walkingSpeedSeries, color: .teal, unit: "m/s")
        }

        // Cadence
        if !viewModel.cadenceSeries.isEmpty {
            timeSeriesChart(title: "Cadence", data: viewModel.cadenceSeries, color: .green, unit: "SPM")
        }

        // Stride length
        if !viewModel.strideSeries.isEmpty {
            timeSeriesChart(title: "Stride Length", data: viewModel.strideSeries, color: .orange, unit: "m")
        }

        // Sway velocity
        if !viewModel.swayVelocitySeries.isEmpty {
            timeSeriesChart(title: "Sway Velocity", data: viewModel.swayVelocitySeries, color: .red, unit: "mm/s")
        }

        // REBA
        if !viewModel.rebaSeries.isEmpty {
            timeSeriesChart(title: "REBA Score", data: viewModel.rebaSeries, color: .indigo, unit: "")
        }

        // Hip ROM
        if !viewModel.hipFlexionLeftSeries.isEmpty {
            dualSeriesChart(
                title: "Hip Flexion",
                leftData: viewModel.hipFlexionLeftSeries,
                rightData: viewModel.hipFlexionRightSeries,
                unit: "°"
            )
        }

        // Knee ROM
        if !viewModel.kneeFlexionLeftSeries.isEmpty {
            dualSeriesChart(
                title: "Knee Flexion",
                leftData: viewModel.kneeFlexionLeftSeries,
                rightData: viewModel.kneeFlexionRightSeries,
                unit: "°"
            )
        }
    }

    // MARK: - Time Series Chart

    @ViewBuilder
    private func timeSeriesChart(title: String, data: [TimeSeriesPoint], color: Color, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Chart(data) { point in
                LineMark(
                    x: .value("Time (s)", point.time),
                    y: .value(title, point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.gradient)

                AreaMark(
                    x: .value("Time (s)", point.time),
                    y: .value(title, point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.opacity(0.1).gradient)
            }
            .chartXAxisLabel("Time (sec)")
            .chartYAxisLabel(unit)
            .frame(height: 200)
            .accessibilityChartDescriptor(
                SessionChartDescriptor(title: title, data: data, unit: unit)
            )
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Dual Series Chart (Left/Right)

    @ViewBuilder
    private func dualSeriesChart(title: String, leftData: [TimeSeriesPoint], rightData: [TimeSeriesPoint], unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Chart {
                ForEach(leftData) { point in
                    LineMark(
                        x: .value("Time (s)", point.time),
                        y: .value(title, point.value),
                        series: .value("Side", "Left")
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)
                }

                ForEach(rightData) { point in
                    LineMark(
                        x: .value("Time (s)", point.time),
                        y: .value(title, point.value),
                        series: .value("Side", "Right")
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.red)
                }
            }
            .chartXAxisLabel("Time (sec)")
            .chartYAxisLabel(unit)
            .chartForegroundStyleScale(["Left": Color.blue, "Right": Color.red])
            .chartLegend(position: .bottom)
            .frame(height: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Step Analysis

    @ViewBuilder
    private var stepAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step Analysis")
                .font(.headline)

            HStack(spacing: 16) {
                if let left = viewModel.leftFootStats {
                    footCard(side: "Left", stats: left, color: .blue)
                }
                if let right = viewModel.rightFootStats {
                    footCard(side: "Right", stats: right, color: .red)
                }
            }

            if let sym = viewModel.symmetryRatio {
                HStack {
                    Text("Symmetry")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.0f%%", sym * 100))
                        .font(.subheadline.bold())
                        .foregroundStyle(sym > 0.9 ? .green : sym > 0.8 ? .yellow : .red)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func footCard(side: String, stats: FootStats, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(side)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(String(format: "%.2f m", stats.avgStride))
                .font(.title3.bold())
            Text("\(stats.count) steps")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func severityColor(_ severity: ClinicalSeverity) -> Color {
        switch severity {
        case .normal: return .green
        case .mild: return .yellow
        case .moderate: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Audio Graph Descriptor

private struct SessionChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let data: [TimeSeriesPoint]
    let unit: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let values = data.map(\.value)
        let times = data.map(\.time)
        let minVal = values.min() ?? 0
        let maxVal = max(values.max() ?? 1, minVal + 0.1)
        let maxTime = times.max() ?? 1

        let xAxis = AXNumericDataAxisDescriptor(
            title: "Time (seconds)",
            range: 0...maxTime,
            gridlinePositions: []
        ) { val in String(format: "%.0fs", val) }

        let yAxis = AXNumericDataAxisDescriptor(
            title: title,
            range: minVal...maxVal,
            gridlinePositions: []
        ) { val in String(format: "%.1f \(unit)", val) }

        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: true,
            dataPoints: data.map { AXDataPoint(x: $0.time, y: $0.value) }
        )

        return AXChartDescriptor(
            title: title,
            summary: "Time series of \(title.lowercased()) during the session.",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: GaitSession(
            date: .now,
            duration: 120,
            averageCadenceSPM: 112,
            averageStrideLengthM: 0.72,
            averageTrunkLeanDeg: 5.3,
            postureScore: 82
        ))
    }
}
