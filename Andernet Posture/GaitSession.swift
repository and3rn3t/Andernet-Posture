import Foundation
import SwiftData

@Model
final class GaitSession {
    var date: Date
    var duration: TimeInterval
    var averageCadenceSPM: Double?
    var averageStrideLengthM: Double?
    var averageTrunkLeanDeg: Double?

    init(date: Date = .now,
         duration: TimeInterval = 0,
         averageCadenceSPM: Double? = nil,
         averageStrideLengthM: Double? = nil,
         averageTrunkLeanDeg: Double? = nil) {
        self.date = date
        self.duration = duration
        self.averageCadenceSPM = averageCadenceSPM
        self.averageStrideLengthM = averageStrideLengthM
        self.averageTrunkLeanDeg = averageTrunkLeanDeg
    }
}
