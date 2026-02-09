//
//  SessionListView.swift
//  Andernet Posture
//
//  iOS 26 HIG: Large title, scroll edge effects, swipe actions.
//

import SwiftUI
import SwiftData

struct SessionListView: View {
    @Query(sort: \GaitSession.date, order: .reverse) private var sessions: [GaitSession]
    @Environment(\.modelContext) private var modelContext
    @State private var compareMode = false
    @State private var selectedForCompare: Set<PersistentIdentifier> = []
    @State private var navigateToComparison = false

    /// The two sessions chosen for comparison (baseline = earlier date).
    private var comparisonPair: (GaitSession, GaitSession)? {
        guard selectedForCompare.count == 2 else { return nil }
        let picked = sessions.filter { selectedForCompare.contains($0.persistentModelID) }
        guard picked.count == 2 else { return nil }
        let sorted = picked.sorted { $0.date < $1.date }
        return (sorted[0], sorted[1])
    }

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "figure.walk.circle",
                        description: Text("Complete a capture session to see it here.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(sessions) { session in
                        if compareMode {
                            compareRow(session: session)
                        } else {
                            NavigationLink(value: session) {
                                SessionRow(session: session)
                            }
                        }
                    }
                    .onDelete { offsets in
                        if !compareMode {
                            deleteSessions(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationDestination(for: GaitSession.self) { session in
                SessionDetailView(session: session)
            }
            .navigationDestination(isPresented: $navigateToComparison) {
                if let pair = comparisonPair {
                    ComparisonView(baseline: pair.0, current: pair.1)
                } else {
                    EmptyView()
                }
            }
            .toolbar(content: sessionToolbar)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func sessionToolbar() -> some ToolbarContent {
        if !sessions.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation {
                        compareMode.toggle()
                        if !compareMode {
                            selectedForCompare.removeAll()
                        }
                    }
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .symbolVariant(compareMode ? .fill : .none)
                }
                .accessibilityLabel(
                    compareMode ? "Exit compare mode" : "Compare sessions"
                )
            }
            ToolbarItem(placement: .topBarTrailing) {
                if compareMode {
                    compareButton
                } else {
                    EditButton()
                }
            }
        }
    }

    // MARK: - Compare Mode Helpers

    @ViewBuilder
    private func compareRow(session: GaitSession) -> some View {
        let isSelected = selectedForCompare.contains(session.persistentModelID)
        Button {
            toggleSelection(session)
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .imageScale(.large)
                SessionRow(session: session)
            }
        }
        .tint(.primary)
    }

    private func toggleSelection(_ session: GaitSession) {
        let id = session.persistentModelID
        if selectedForCompare.contains(id) {
            selectedForCompare.remove(id)
        } else if selectedForCompare.count < 2 {
            selectedForCompare.insert(id)
        }
    }

    @ViewBuilder
    private var compareButton: some View {
        Button("Compare") {
            navigateToComparison = true
        }
        .disabled(selectedForCompare.count != 2)
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: GaitSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.date, style: .date)
                    .font(.headline)
                Spacer()
                if let score = session.postureScore {
                    PostureScoreBadge(score: score)
                }
            }

            HStack(spacing: 16) {
                Label(session.formattedDuration, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let cadence = session.averageCadenceSPM {
                    Label(String(format: "%.0f SPM", cadence), systemImage: "metronome")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let steps = session.totalSteps, steps > 0 {
                    Label("\(steps) steps", systemImage: "shoeprints.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Posture Score Badge

struct PostureScoreBadge: View {
    let score: Double

    var body: some View {
        Text(String(format: "%.0f", score))
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(scoreColor.opacity(0.2), in: Capsule())
            .foregroundStyle(scoreColor)
    }

    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}

#Preview {
    SessionListView()
        .modelContainer(for: GaitSession.self, inMemory: true)
}
