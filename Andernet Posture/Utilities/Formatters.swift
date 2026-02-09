//
//  Formatters.swift
//  Andernet Posture
//
//  Shared formatting utilities.
//

import Foundation

extension TimeInterval {
    /// Format as "M:SS" string.
    var mmss: String {
        let total = Int(self)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format as "M:SS.t" string (with tenths of a second).
    var mmssWithTenths: String {
        let total = Int(self)
        let minutes = total / 60
        let seconds = total % 60
        let tenths = Int((self - Double(total)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    /// Format as "Hh Mm" for longer durations.
    var longForm: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}

extension Double {
    /// Format as degrees string.
    var degreesString: String {
        String(format: "%.1f°", self)
    }

    /// Format as percentage string.
    var percentString: String {
        String(format: "%.0f%%", self)
    }

    /// Format as meters string.
    var metersString: String {
        String(format: "%.2f m", self)
    }
}
