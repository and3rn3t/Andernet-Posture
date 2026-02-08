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
                        NavigationLink(value: session) {
                            SessionRow(session: session)
                        }
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
            .navigationTitle("Sessions")
            .navigationDestination(for: GaitSession.self) { session in
                SessionDetailView(session: session)
            }
            .toolbar {
                if !sessions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
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
