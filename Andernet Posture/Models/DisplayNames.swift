//
//  DisplayNames.swift
//  Andernet Posture
//
//  Centralized display-name helpers for clinical classification strings.
//

import Foundation

extension String {

    /// Human-readable label for a Kendall posture classification raw value.
    var kendallDisplayName: String {
        switch self {
        case "ideal":             return "Ideal"
        case "kyphosisLordosis":  return "Kyphosis-Lordosis"
        case "flatBack":          return "Flat Back"
        case "swayBack":          return "Sway Back"
        default:                  return self.capitalized
        }
    }

    /// Abbreviated Kendall label for compact UI contexts (dashboard cards).
    var kendallShortName: String {
        switch self {
        case "ideal":             return "Ideal"
        case "kyphosisLordosis":  return "Kypho-Lord"
        case "flatBack":          return "Flat Back"
        case "swayBack":          return "Sway Back"
        default:                  return self.capitalized
        }
    }

    /// Human-readable label for a gait pattern classification raw value.
    var patternDisplayName: String {
        switch self {
        case "normal":         return "Normal"
        case "antalgic":       return "Antalgic"
        case "trendelenburg":  return "Trendelenburg"
        case "festinating":    return "Festinating"
        case "circumduction":  return "Circumduction"
        case "ataxic":         return "Ataxic"
        case "waddling":       return "Waddling"
        case "steppage":       return "Steppage"
        default:               return self.capitalized
        }
    }
}
