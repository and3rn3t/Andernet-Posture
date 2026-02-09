//
//  PostureGaitCaptureView.swift
//  Andernet Posture
//
//  iOS 26 HIG: Clear Liquid Glass overlays on AR camera, full-screen immersive,
//  start/pause/stop controls, live metrics, timer, calibration flow.
//

import SwiftUI
import SwiftData

struct PostureGaitCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CaptureViewModel()
    @State private var showSavedAlert = false
    @AppStorage("skeletonOverlay") private var skeletonOverlay = true
    @AppStorage("samplingRate") private var samplingRate = 60.0

    var body: some View {
        ZStack {
            // Full-screen AR body tracking
            BodyARView(viewModel: viewModel, showSkeleton: skeletonOverlay, samplingRate: samplingRate)
                .ignoresSafeArea()

            // Darkened overlay for readability on camera feed
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                // MARK: - Top metrics bar
                topMetricsBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                // MARK: - Calibration prompt
                if viewModel.recordingState == .calibrating {
                    calibrationOverlay
                }

                // MARK: - Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 8)
                }

                // MARK: - Bottom control bar
                bottomControls
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
        }
        .statusBarHidden()
        .alert("Session Saved", isPresented: $showSavedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your posture and gait data has been recorded.")
        }
    }

    // MARK: - Top Metrics

    @ViewBuilder
    private var topMetricsBar: some View {
        HStack(spacing: 12) {
            // Timer
            VStack(spacing: 2) {
                Image(systemName: "timer")
                    .font(.caption2)
                Text(formattedTime)
                    .font(.system(.body, design: .monospaced).bold())
            }

            Divider().frame(height: 36)

            // Posture score
            VStack(spacing: 2) {
                Image(systemName: "figure.stand")
                    .font(.caption2)
                Text(String(format: "%.0f", viewModel.postureScore))
                    .font(.system(.body, design: .rounded).bold())
            }

            Divider().frame(height: 36)

            // Trunk lean
            VStack(spacing: 2) {
                Image(systemName: "arrow.up.and.down")
                    .font(.caption2)
                Text(String(format: "%.1f°", viewModel.trunkLeanDeg))
                    .font(.system(.body, design: .rounded).bold())
            }

            Divider().frame(height: 36)

            // Cadence
            VStack(spacing: 2) {
                Image(systemName: "metronome")
                    .font(.caption2)
                Text(String(format: "%.0f", viewModel.cadenceSPM))
                    .font(.system(.body, design: .rounded).bold())
            }

            Divider().frame(height: 36)

            // Steps
            VStack(spacing: 2) {
                Image(systemName: "shoeprints.fill")
                    .font(.caption2)
                Text("\(viewModel.stepCount)")
                    .font(.system(.body, design: .rounded).bold())
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Calibration

    @ViewBuilder
    private var calibrationOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.stand")
                .font(.system(size: 60))
                .foregroundStyle(.white)
                .symbolEffect(.pulse)

            Text("Stand naturally in frame")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Calibrating...")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(32)
        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Bottom Controls

    @ViewBuilder
    private var bottomControls: some View {
        HStack(spacing: 24) {
            switch viewModel.recordingState {
            case .idle:
                // Start button
                Button {
                    viewModel.startCapture()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)

                // Close
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

            case .calibrating:
                // Cancel during calibration
                Button {
                    dismiss()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

            case .recording:
                // Pause
                Button {
                    viewModel.togglePause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                // Stop
                Button {
                    viewModel.stopCapture()
                    if let _ = viewModel.saveSession(context: modelContext) {
                        showSavedAlert = true
                    }
                } label: {
                    Label("Stop & Save", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)

            case .paused:
                // Resume
                Button {
                    viewModel.togglePause()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)

                // Stop
                Button {
                    viewModel.stopCapture()
                    if let _ = viewModel.saveSession(context: modelContext) {
                        showSavedAlert = true
                    }
                } label: {
                    Label("Stop & Save", systemImage: "stop.fill")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

            case .finished:
                // Done
                Button {
                    dismiss()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Helpers

    private var formattedTime: String {
        let total = Int(viewModel.elapsedTime)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    PostureGaitCaptureView()
        .modelContainer(for: GaitSession.self, inMemory: true)
}
