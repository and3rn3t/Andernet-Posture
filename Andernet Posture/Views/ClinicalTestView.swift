//
//  ClinicalTestView.swift
//  Andernet Posture
//
//  iOS 26 HIG: Guided clinical test protocols with step-by-step instructions,
//  countdown timers, and results display.
//

import SwiftUI

struct ClinicalTestView: View {
    @State private var viewModel = ClinicalTestViewModel()
    @State private var selectedTest: ClinicalTestType?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.testType == nil {
                    testSelectionView
                } else {
                    activeTestView
                }
            }
            .navigationTitle("Clinical Tests")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Test Selection

    @ViewBuilder
    private var testSelectionView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Disclaimer banner
                HStack(spacing: 12) {
                    Image(systemName: "stethoscope")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Guided Clinical Protocols")
                            .font(.headline)
                        Text("Standardized tests for mobility, balance, and functional capacity assessment.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

                // TUG
                testCard(
                    title: "Timed Up & Go (TUG)",
                    description: "Measures functional mobility. Stand from a chair, walk 3m, turn, return, and sit.",
                    duration: "~30 sec",
                    icon: "figure.walk.arrival",
                    color: .green
                ) {
                    viewModel.startTUG()
                }

                // Romberg
                testCard(
                    title: "Romberg Balance Test",
                    description: "Assesses proprioceptive balance. Stand still for 30s eyes open, then 30s eyes closed.",
                    duration: "~2 min",
                    icon: "figure.stand",
                    color: .purple
                ) {
                    viewModel.startRomberg()
                }

                // 6MWT
                testCard(
                    title: "6-Minute Walk Test",
                    description: "Evaluates functional exercise capacity. Walk at your normal pace for 6 minutes.",
                    duration: "6 min",
                    icon: "figure.walk",
                    color: .orange
                ) {
                    viewModel.start6MWT()
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func testCard(title: String, description: String, duration: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(color)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(duration)
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active Test View

    @ViewBuilder
    private var activeTestView: some View {
        VStack(spacing: 24) {
            Spacer()

            // State-specific content
            switch viewModel.testState {
            case .notStarted:
                EmptyView()

            case .instructing(let step, let totalSteps, let instruction):
                instructionView(step: step, totalSteps: totalSteps, instruction: instruction)

            case .countdown(let seconds):
                countdownView(seconds: seconds)

            case .running(let phaseLabel):
                runningView(phaseLabel: phaseLabel)

            case .transitioning(let instruction):
                transitionView(instruction: instruction)

            case .completed:
                resultsView

            case .cancelled:
                cancelledView
            }

            Spacer()

            // Controls
            testControls
        }
        .padding()
    }

    // MARK: - Instruction View

    @ViewBuilder
    private func instructionView(step: Int, totalSteps: Int, instruction: String) -> some View {
        VStack(spacing: 20) {
            // Progress
            HStack(spacing: 4) {
                ForEach(1...totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? .blue : .gray.opacity(0.3))
                        .frame(height: 4)
                }
            }

            Text("Step \(step) of \(totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(instruction)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Countdown

    @ViewBuilder
    private func countdownView(seconds: Int) -> some View {
        VStack(spacing: 16) {
            Text("\(seconds)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
                .contentTransition(.numericText())

            Text("Get ready...")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Running

    @ViewBuilder
    private func runningView(phaseLabel: String) -> some View {
        VStack(spacing: 20) {
            // Timer
            Text(formatTime(viewModel.elapsedTime > 0 ? viewModel.elapsedTime : viewModel.phaseElapsedTime))
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)

            Text(phaseLabel)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if viewModel.testType == .sixMinuteWalk {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f m", viewModel.sixMWTDistance))
                        .font(.title.bold())
                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            // Pulsing indicator
            Circle()
                .fill(.red)
                .frame(width: 16, height: 16)
                .shadow(color: .red.opacity(0.5), radius: 8)
                .symbolEffect(.pulse)
        }
    }

    // MARK: - Transition

    @ViewBuilder
    private func transitionView(instruction: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.forward.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .symbolEffect(.bounce)

            Text(instruction)
                .font(.title3)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Test Complete")
                .font(.title.bold())

            // Test-specific results
            switch viewModel.testType {
            case .timedUpAndGo:
                if let result = viewModel.tugResult {
                    tugResultView(result)
                }

            case .romberg:
                if let result = viewModel.rombergResult {
                    rombergResultView(result)
                }

            case .sixMinuteWalk:
                if let result = viewModel.sixMWTResult {
                    sixMWTResultView(result)
                }

            case .none:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func tugResultView(_ result: TUGResult) -> some View {
        VStack(spacing: 12) {
            resultRow("Time", value: String(format: "%.1f sec", result.timeSec))
            resultRow("Fall Risk", value: result.fallRisk.rawValue.capitalized,
                       severity: result.fallRisk == .low ? .normal : result.fallRisk == .moderate ? .moderate : .severe)
            resultRow("Mobility", value: result.mobilityLevel)

            Text("Ref: Shumway-Cook et al., 2000 (fall risk >13.5s)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func rombergResultView(_ result: RombergResult) -> some View {
        VStack(spacing: 12) {
            resultRow("Eyes Open Sway", value: String(format: "%.1f mm/s", result.eyesOpenSwayVelocity))
            resultRow("Eyes Closed Sway", value: String(format: "%.1f mm/s", result.eyesClosedSwayVelocity))
            resultRow("Romberg Ratio", value: String(format: "%.2f", result.ratio),
                       severity: result.ratio <= 2.0 ? .normal : .moderate)

            Text("Ratio >2.0 suggests proprioceptive/vestibular deficit")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func sixMWTResultView(_ result: SixMinuteWalkResult) -> some View {
        VStack(spacing: 12) {
            resultRow("Distance", value: String(format: "%.0f m", result.distanceM))
            if let predicted = result.predictedDistanceM {
                resultRow("Predicted", value: String(format: "%.0f m", predicted))
            }
            if let pctPredicted = result.percentPredicted {
                resultRow("% Predicted", value: String(format: "%.0f%%", pctPredicted),
                           severity: pctPredicted >= 80 ? .normal : pctPredicted >= 60 ? .mild : .moderate)
            }
            resultRow("Classification", value: result.classification)

            Text("Ref: Enright & Sherrill, 1998")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func resultRow(_ label: String, value: String, severity: ClinicalSeverity? = nil) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Text(value)
                    .font(.subheadline.bold())
                if let severity {
                    Circle()
                        .fill(severityColor(severity))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }

    // MARK: - Cancelled

    @ViewBuilder
    private var cancelledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Test Cancelled")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var testControls: some View {
        HStack(spacing: 16) {
            switch viewModel.testState {
            case .instructing:
                Button {
                    advanceCurrentTest()
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    viewModel.cancelTest()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

            case .running:
                if viewModel.testType == .timedUpAndGo {
                    Button {
                        viewModel.completeTUG()
                    } label: {
                        Label("Done — Seated", systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.green)
                }

                if viewModel.testType == .sixMinuteWalk {
                    Button {
                        viewModel.complete6MWT()
                    } label: {
                        Label("Stop Early", systemImage: "stop.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button {
                    viewModel.cancelTest()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

            case .completed, .cancelled:
                Button {
                    viewModel.testType = nil
                    viewModel.testState = .notStarted
                } label: {
                    Label("Back to Tests", systemImage: "arrow.backward")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            default:
                EmptyView()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Helpers

    private func advanceCurrentTest() {
        switch viewModel.testType {
        case .timedUpAndGo: viewModel.advanceTUG()
        case .romberg: viewModel.advanceRomberg()
        case .sixMinuteWalk: viewModel.advance6MWT()
        case .none: break
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time - Double(Int(time))) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
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

#Preview {
    ClinicalTestView()
}
