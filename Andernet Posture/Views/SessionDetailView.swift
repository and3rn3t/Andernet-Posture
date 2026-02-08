//
//  SessionDetailView.swift
//  Andernet Posture
//
//  iOS 26 HIG: Grouped sections, Swift Charts with Audio Graphs, Liquid Glass material.
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

                // MARK: - Posture Charts
                if !viewModel.trunkLeanSeries.isEmpty {
                    timeSeriesChart(
                        title: "Trunk Lean",
                        data: viewModel.trunkLeanSeries,
                        color: .blue,
                        unit: "°"
                    )
                }

                if !viewModel.lateralLeanSeries.isEmpty {
                    timeSeriesChart(
                        title: "Lateral Lean",
                        data: viewModel.lateralLeanSeries,
                        color: .purple,
                        unit: "°"
                    )
                }

                // MARK: - Gait Charts
                if !viewModel.cadenceSeries.isEmpty {
                    timeSeriesChart(
                        title: "Cadence",
                        data: viewModel.cadenceSeries,
                        color: .green,
                        unit: "SPM"
                    )
                }

                if !viewModel.strideSeries.isEmpty {
                    timeSeriesChart(
                        title: "Stride Length",
                        data: viewModel.strideSeries,
                        color: .orange,
                        unit: "m"
                    )
                }

                // MARK: - Step Analysis
                if viewModel.leftFootStats != nil || viewModel.rightFootStats != nil {
                    stepAnalysisSection
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.session.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.large)
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
