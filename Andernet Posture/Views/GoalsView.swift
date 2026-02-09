//
//  GoalsView.swift
//  Andernet Posture
//
//  Goal tracking view with progress rings and adjustable targets.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - GoalConfig

/// Persisted goal targets with sensible clinical defaults.
struct GoalConfig: Codable {
    var sessionsPerWeek: Int = 5
    var targetPostureScore: Double = 80
    var targetWalkingSpeed: Double = 1.2
    var targetCadence: Double = 110

    static let `default` = GoalConfig()
}

// MARK: - GoalsView

struct GoalsView: View {
    @Query(sort: \GaitSession.date, order: .reverse) private var sessions: [GaitSession]
    @AppStorage("goalsJSON") private var goalsJSON: String = ""

    @State private var goals: GoalConfig = .default

    var body: some View {
        NavigationStack {
            Form {
                Section("Weekly Targets") {
                    goalRow(
                        icon: "calendar.badge.clock",
                        label: "Sessions / Week",
                        value: "\(goals.sessionsPerWeek)",
                        content: {
                            Stepper(
                                "\(goals.sessionsPerWeek) sessions",
                                value: $goals.sessionsPerWeek,
                                in: 1...14
                            )
                            .onChange(of: goals.sessionsPerWeek) { _, _ in saveGoals() }
                        }
                    )

                    goalRow(
                        icon: "figure.stand",
                        label: "Target Posture Score",
                        value: String(format: "%.0f", goals.targetPostureScore),
                        content: {
                            VStack {
                                Slider(value: $goals.targetPostureScore, in: 40...100, step: 5)
                                    .onChange(of: goals.targetPostureScore) { _, _ in saveGoals() }
                                HStack {
                                    Text("40").font(.caption2).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("100").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    )

                    goalRow(
                        icon: "speedometer",
                        label: "Target Walking Speed",
                        value: String(format: "%.1f m/s", goals.targetWalkingSpeed),
                        content: {
                            VStack {
                                Slider(value: $goals.targetWalkingSpeed, in: 0.5...2.0, step: 0.1)
                                    .onChange(of: goals.targetWalkingSpeed) { _, _ in saveGoals() }
                                HStack {
                                    Text("0.5").font(.caption2).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("2.0 m/s").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    )

                    goalRow(
                        icon: "metronome.fill",
                        label: "Target Cadence",
                        value: String(format: "%.0f SPM", goals.targetCadence),
                        content: {
                            VStack {
                                Slider(value: $goals.targetCadence, in: 60...160, step: 5)
                                    .onChange(of: goals.targetCadence) { _, _ in saveGoals() }
                                HStack {
                                    Text("60").font(.caption2).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("160 SPM").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    )
                }

                Section("This Week's Progress") {
                    progressRingRow(
                        label: "Sessions",
                        icon: "calendar.badge.clock",
                        current: Double(weeklySessionCount),
                        target: Double(goals.sessionsPerWeek),
                        color: .blue
                    )

                    progressRingRow(
                        label: "Posture Score",
                        icon: "figure.stand",
                        current: weeklyAveragePostureScore ?? 0,
                        target: goals.targetPostureScore,
                        color: .green
                    )

                    progressRingRow(
                        label: "Walking Speed",
                        icon: "speedometer",
                        current: weeklyAverageWalkingSpeed ?? 0,
                        target: goals.targetWalkingSpeed,
                        color: .teal
                    )

                    progressRingRow(
                        label: "Cadence",
                        icon: "metronome.fill",
                        current: weeklyAverageCadence ?? 0,
                        target: goals.targetCadence,
                        color: .orange
                    )
                }
            }
            .navigationTitle("Goals")
            .onAppear { loadGoals() }
        }
    }

    // MARK: - Weekly Stats (computed from SwiftData)

    private var weeklySessionCount: Int {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return sessions.filter { $0.date >= startOfWeek }.count
    }

    private var weeklyAveragePostureScore: Double? {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let scores = sessions
            .filter { $0.date >= startOfWeek }
            .compactMap(\.postureScore)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private var weeklyAverageWalkingSpeed: Double? {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let speeds = sessions
            .filter { $0.date >= startOfWeek }
            .compactMap(\.averageWalkingSpeedMPS)
        guard !speeds.isEmpty else { return nil }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    private var weeklyAverageCadence: Double? {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let cadences = sessions
            .filter { $0.date >= startOfWeek }
            .compactMap(\.averageCadenceSPM)
        guard !cadences.isEmpty else { return nil }
        return cadences.reduce(0, +) / Double(cadences.count)
    }

    // MARK: - Persistence

    private func loadGoals() {
        guard !goalsJSON.isEmpty,
              let data = goalsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(GoalConfig.self, from: data) else {
            goals = .default
            return
        }
        goals = decoded
    }

    private func saveGoals() {
        guard let data = try? JSONEncoder().encode(goals),
              let json = String(data: data, encoding: .utf8) else { return }
        goalsJSON = json
    }

    // MARK: - Subviews

    @ViewBuilder
    private func goalRow<Content: View>(
        icon: String,
        label: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(label)
                    .font(.subheadline.bold())
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func progressRingRow(
        label: String,
        icon: String,
        current: Double,
        target: Double,
        color: Color
    ) -> some View {
        let progress = target > 0 ? min(current / target, 1.0) : 0

        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatProgress(current: current, target: target, label: label))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatProgress(current: Double, target: Double, label: String) -> String {
        switch label {
        case "Sessions":
            return "\(Int(current)) / \(Int(target))"
        case "Posture Score":
            return String(format: "%.0f / %.0f", current, target)
        case "Walking Speed":
            return String(format: "%.2f / %.1f m/s", current, target)
        case "Cadence":
            return String(format: "%.0f / %.0f SPM", current, target)
        default:
            return String(format: "%.1f / %.1f", current, target)
        }
    }
}

#Preview {
    GoalsView()
        .modelContainer(for: GaitSession.self, inMemory: true)
}
