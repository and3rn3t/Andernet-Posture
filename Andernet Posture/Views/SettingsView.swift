//
//  SettingsView.swift
//  Andernet Posture
//
//  iOS 26 HIG: Grouped Form style, SF Symbols without borders.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("skeletonOverlay") private var skeletonOverlay = true
    @AppStorage("healthKitSync") private var healthKitSync = false
    @AppStorage("samplingRate") private var samplingRate = 60.0

    @State private var healthKitService: DefaultHealthKitService? = DefaultHealthKitService()
    @State private var healthKitAuthorized = false
    @State private var showingHealthKitError = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Capture Settings
                Section("Capture") {
                    Toggle("Skeleton Overlay", systemImage: "figure.stand", isOn: $skeletonOverlay)

                    Toggle("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right", isOn: $hapticFeedback)

                    HStack {
                        Label("Sampling Rate", systemImage: "waveform")
                        Spacer()
                        Picker("", selection: $samplingRate) {
                            Text("30 Hz").tag(30.0)
                            Text("60 Hz").tag(60.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                }

                // MARK: - HealthKit
                Section("Health") {
                    Toggle("Sync to HealthKit", systemImage: "heart.fill", isOn: $healthKitSync)
                        .onChange(of: healthKitSync) { _, enabled in
                            if enabled {
                                requestHealthKit()
                            }
                        }

                    if healthKitSync && healthKitAuthorized {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                // MARK: - About
                Section("About") {
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    }
                    
                    LabeledContent("Build") {
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    }

                    Link(destination: URL(string: "https://andernet.dev")!) {
                        Label("Andernet.dev", systemImage: "globe")
                    }
                }

                // MARK: - Data
                Section("Data") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("Manage Data", systemImage: "externaldrive.fill")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .alert("HealthKit Error", isPresented: $showingHealthKitError) {
            Button("OK") { healthKitSync = false }
        } message: {
            Text("Unable to connect to HealthKit. Please enable access in Settings > Privacy > Health.")
        }
    }

    private func requestHealthKit() {
        Task {
            do {
                try await healthKitService?.requestAuthorization()
                healthKitAuthorized = true
            } catch {
                showingHealthKitError = true
            }
        }
    }
}

// MARK: - Data Management

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [GaitSession]
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                LabeledContent("Total Sessions") {
                    Text("\(sessions.count)")
                }
                LabeledContent("Total Duration") {
                    let total = sessions.reduce(0) { $0 + $1.duration }
                    let minutes = Int(total) / 60
                    Text("\(minutes) min")
                }
            }

            Section {
                Button("Delete All Sessions", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("Manage Data")
        .confirmationDialog(
            "Delete All Sessions",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                for session in sessions {
                    modelContext.delete(session)
                }
                try? modelContext.save()
            }
        } message: {
            Text("This will permanently delete all \(sessions.count) sessions. This action cannot be undone.")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: GaitSession.self, inMemory: true)
}
