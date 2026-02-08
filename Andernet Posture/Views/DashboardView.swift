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

                    // MARK: - Posture Score Trend
                    if !viewModel.postureScoreTrend.isEmpty {
                        trendChart(
                            title: "Posture Score",
                            data: viewModel.postureScoreTrend,
                            color: .blue,
                            unit: ""
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
                title: "Sessions",
                value: "\(viewModel.totalSessions)",
                subtitle: viewModel.formattedTotalTime,
                icon: "clock.fill"
            )
        }
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
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    var score: Double? = nil
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
