import SwiftUI

struct PostureGaitCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var startDate = Date()
    @StateObject private var metrics = MetricsModel()

    var body: some View {
        ZStack(alignment: .topLeading) {
            BodyARView(metrics: metrics)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: "Trunk lean: %.1f°", metrics.trunkLeanDegrees))
                Text(String(format: "Cadence: %.0f spm", metrics.cadenceSPM))
                Text(String(format: "Avg stride: %.2f m", metrics.avgStrideLengthM))
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
        }
        .overlay(alignment: .topTrailing) {
            Button("Done") {
                saveAndDismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    private func saveAndDismiss() {
        let session = GaitSession(
            date: Date(),
            duration: Date().timeIntervalSince(startDate),
            averageCadenceSPM: metrics.cadenceSPM,
            averageStrideLengthM: metrics.avgStrideLengthM,
            averageTrunkLeanDeg: metrics.trunkLeanDegrees
        )
        modelContext.insert(session)
        dismiss()
    }
}

#Preview {
    PostureGaitCaptureView()
}
