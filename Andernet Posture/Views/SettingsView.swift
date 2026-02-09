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
    @AppStorage("userAge") private var userAge = 0
    @AppStorage("userSex") private var userSex = "notSet"  // "male", "female", "notSet"
    @AppStorage("clinicalDisclaimerAccepted") private var disclaimerAccepted = false
    @AppStorage("showNormativeRanges") private var showNormativeRanges = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var healthKitService: DefaultHealthKitService? = DefaultHealthKitService()
    @State private var healthKitAuthorized = false
    @State private var showingHealthKitError = false
    @State private var showingDisclaimer = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Clinical Disclaimer
                if !disclaimerAccepted {
                    Section {
                        Button {
                            showingDisclaimer = true
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Clinical Disclaimer Required")
                                        .font(.subheadline.bold())
                                    Text("Please review before using clinical features")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                // MARK: - Demographics (Normative Ranges)
                Section {
                    Picker("Age Range", selection: $userAge) {
                        Text("Not Set").tag(0)
                        Text("20–29").tag(25)
                        Text("30–39").tag(35)
                        Text("40–49").tag(45)
                        Text("50–59").tag(55)
                        Text("60–69").tag(65)
                        Text("70–79").tag(75)
                        Text("80+").tag(85)
                    }

                    Picker("Biological Sex", selection: $userSex) {
                        Text("Not Set").tag("notSet")
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                    }

                    Toggle("Show Normative Ranges", systemImage: "chart.bar.doc.horizontal", isOn: $showNormativeRanges)
                } header: {
                    Text("Demographics")
                } footer: {
                    Text("Age and sex are used to display age-stratified normative ranges for clinical measurements. This data stays on-device.")
                }

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

                // MARK: - AR Overlay
                AROverlaySettingsSection()

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

                // MARK: - Clinical Tools
                Section {
                    NavigationLink {
                        ClinicalTestView()
                    } label: {
                        Label("Clinical Test Protocols", systemImage: "stethoscope")
                    }
                } header: {
                    Text("Clinical Tools")
                } footer: {
                    Text("Run guided TUG, Romberg, and 6-Minute Walk protocols.")
                }

                // MARK: - Disclaimer
                Section {
                    Button {
                        showingDisclaimer = true
                    } label: {
                        Label("View Clinical Disclaimer", systemImage: "doc.text.fill")
                    }

                    if disclaimerAccepted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Disclaimer accepted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Legal")
                }

                // MARK: - Support
                Section("Support") {
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("Help & FAQ", systemImage: "questionmark.circle")
                    }

                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                    }
                }

                // MARK: - About
                Section {
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    }
                    
                    LabeledContent("Build") {
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    }

                    Link(destination: URL(string: "https://andernet.dev")!) {
                        Label("Andernet.dev", systemImage: "globe")
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
                } footer: {
                    Text("Made with \u{2764}\u{FE0F} by Andernet")
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
        .sheet(isPresented: $showingDisclaimer) {
            ClinicalDisclaimerSheet(isAccepted: $disclaimerAccepted)
        }
        .onAppear {
            if !disclaimerAccepted {
                showingDisclaimer = true
            }
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

// MARK: - Clinical Disclaimer Sheet

struct ClinicalDisclaimerSheet: View {
    @Binding var isAccepted: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)

                    Text("Clinical Disclaimer")
                        .font(.title.bold())
                        .frame(maxWidth: .infinity)

                    disclaimerText

                    Divider()

                    Button {
                        isAccepted = true
                        dismiss()
                    } label: {
                        Text("I Understand and Accept")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(AppSpacing.lg)
            }
            .navigationTitle("Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var disclaimerText: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Group {
                Text("This application provides posture and gait screening information only.")
                    .bold()

                Text("It is NOT a medical device and should NOT be used for diagnosis, treatment, or medical decision-making.")

                Text("Key limitations:")
                    .font(.subheadline.bold())
                    .padding(.top, 4)

                bulletPoint(
                    "Clinical measurements are proxy estimates derived from camera-based" +
                    " body tracking and may differ from gold-standard laboratory instruments."
                )
                bulletPoint(
                    "ARKit body tracking has inherent accuracy limitations (~5-10° for joint" +
                    " angles) compared to marker-based motion capture systems."
                )
                bulletPoint(
                    "Postural classification, gait pattern detection, and risk assessments" +
                    " are screening tools only and cannot replace clinical evaluation."
                )
                bulletPoint(
                    "Fall risk, frailty, and pain risk scores are composite estimates" +
                    " and should not be used as standalone clinical indicators."
                )
                bulletPoint(
                    "The Fried phenotype frailty screen can assess only 3 of 5 criteria" +
                    " from motion data; a complete assessment requires clinical evaluation."
                )
            }

            Group {
                Text("Always consult a qualified healthcare professional for:")
                    .font(.subheadline.bold())
                    .padding(.top, 4)

                bulletPoint("Any concerns about posture, gait, balance, or fall risk")
                bulletPoint("Interpretation of clinical measurements and risk scores")
                bulletPoint("Development of exercise or treatment programs")
                bulletPoint("Musculoskeletal pain or movement disorders")
            }

            Text("By using this application, you acknowledge that the developers assume no liability for health decisions made based on the app's output.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text("•")
                .font(.body)
            Text(text)
                .font(.subheadline)
        }
        .padding(.leading, AppSpacing.sm)
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
