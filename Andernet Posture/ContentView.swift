//
//  ContentView.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [GaitSession]
    @State private var showingCapture = false

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView("No Sessions Yet",
                                            systemImage: "figure.walk.motion",
                                            description: Text("Tap Capture to record posture and gait."))
                } else {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.date, style: .date)
                                .font(.headline)
                            HStack(spacing: 16) {
                                if let cadence = session.averageCadenceSPM {
                                    Text(String(format: "Cadence: %.0f spm", cadence))
                                        .font(.subheadline)
                                }
                                if let stride = session.averageStrideLengthM {
                                    Text(String(format: "Stride: %.2f m", stride))
                                        .font(.subheadline)
                                }
                                if let lean = session.averageTrunkLeanDeg {
                                    Text(String(format: "Lean: %.1f°", lean))
                                        .font(.subheadline)
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
            .navigationTitle("Posture & Gait")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCapture = true
                    } label: {
                        Label("Capture", systemImage: "camera.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showingCapture) {
                PostureGaitCaptureView()
            }
        }
    }

    private func deleteSessions(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sessions[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: GaitSession.self, inMemory: true)
}
