import Foundation
import SwiftData

@Model
final class GaitSession {
    var date: Date
    var duration: TimeInterval
    var averageCadenceSPM: Double?
    var averageStrideLengthM: Double?
    var averageTrunkLeanDeg: Double?

    // Extended metrics
    var postureScore: Double?
    var peakTrunkLeanDeg: Double?
    var averageLateralLeanDeg: Double?
    var totalSteps: Int?

    // Full time-series data (JSON-encoded for SwiftData efficiency)
    @Attribute(.externalStorage) var framesData: Data?
    @Attribute(.externalStorage) var stepEventsData: Data?

    init(date: Date = .now,
         duration: TimeInterval = 0,
         averageCadenceSPM: Double? = nil,
         averageStrideLengthM: Double? = nil,
         averageTrunkLeanDeg: Double? = nil,
         postureScore: Double? = nil,
         peakTrunkLeanDeg: Double? = nil,
         averageLateralLeanDeg: Double? = nil,
         totalSteps: Int? = nil,
         framesData: Data? = nil,
         stepEventsData: Data? = nil) {
        self.date = date
        self.duration = duration
        self.averageCadenceSPM = averageCadenceSPM
        self.averageStrideLengthM = averageStrideLengthM
        self.averageTrunkLeanDeg = averageTrunkLeanDeg
        self.postureScore = postureScore
        self.peakTrunkLeanDeg = peakTrunkLeanDeg
        self.averageLateralLeanDeg = averageLateralLeanDeg
        self.totalSteps = totalSteps
        self.framesData = framesData
        self.stepEventsData = stepEventsData
    }

    // MARK: - Computed Properties

    /// Lazily decode body frames from stored JSON.
    var decodedFrames: [BodyFrame] {
        guard let data = framesData else { return [] }
        return (try? JSONDecoder().decode([BodyFrame].self, from: data)) ?? []
    }

    /// Lazily decode step events from stored JSON.
    var decodedStepEvents: [StepEvent] {
        guard let data = stepEventsData else { return [] }
        return (try? JSONDecoder().decode([StepEvent].self, from: data)) ?? []
    }

    /// Encode body frames to JSON data.
    static func encode(frames: [BodyFrame]) -> Data? {
        try? JSONEncoder().encode(frames)
    }

    /// Encode step events to JSON data.
    static func encode(stepEvents: [StepEvent]) -> Data? {
        try? JSONEncoder().encode(stepEvents)
    }

    /// Human-readable duration string.
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Posture score label.
    var postureLabel: String {
        guard let score = postureScore else { return "N/A" }
        switch score {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs Improvement"
        }
    }
}
