//
//  CoreMLFatigueAnalyzer.swift
//  Andernet Posture
//
//  CoreML-backed fatigue analyzer. Conforms to the existing
//  FatigueAnalyzer protocol. Falls back to DefaultFatigueAnalyzer
//  when the model isn't available.
//
//  Architecture — temporal summary approach:
//  The FatigueAnalyzer protocol is time-series oriented (recordTimePoint
//  accumulates data, assess() evaluates it). Rather than requiring a
//  sequence model at inference, this wrapper:
//
//  1. Delegates all time-series accumulation to DefaultFatigueAnalyzer
//  2. Extracts the computed trend features (slopes, R², variability)
//  3. Feeds those summary features into a tabular CoreML model
//  4. The ML model predicts a fatigue index and isFatigued label
//
//  This lets us train a simple tabular model in Create ML while still
//  capturing complex non-linear fatigue onset patterns (e.g., posture
//  drops fast but cadence compensates, then both collapse).
//
//  Model architecture (when trained):
//  - Input:  8-feature vector (trend slopes, variability, thirds comparison)
//  - Output: fatigueIndex (0–100), isFatigued (Bool label)
//  - Type:   Regression + binary classification
//

import Foundation
import CoreML
import os.log

private let logger = Logger(subsystem: "dev.andernet.posture", category: "ML.Fatigue")

final class CoreMLFatigueAnalyzer: FatigueAnalyzer {

    private let modelService: MLModelService
    private let fallback = DefaultFatigueAnalyzer()

    init(modelService: MLModelService) {
        self.modelService = modelService
    }

    // MARK: - FatigueAnalyzer Protocol

    /// Delegate time-point accumulation to the rule-based analyzer.
    /// Both this wrapper and the fallback share the same accumulated data
    /// because the fallback IS the data accumulator.
    func recordTimePoint(
        timestamp: TimeInterval,
        postureScore: Double,
        trunkLeanDeg: Double,
        lateralLeanDeg: Double,
        cadenceSPM: Double,
        walkingSpeedMPS: Double
    ) {
        fallback.recordTimePoint(
            timestamp: timestamp,
            postureScore: postureScore,
            trunkLeanDeg: trunkLeanDeg,
            lateralLeanDeg: lateralLeanDeg,
            cadenceSPM: cadenceSPM,
            walkingSpeedMPS: walkingSpeedMPS
        )
    }

    func assess() -> FatigueAssessment {
        // Always compute the rule-based assessment first — it provides
        // both the fallback result and the summary features for ML.
        let ruleResult = fallback.assess()

        guard modelService.useMLModels,
              let model = modelService.loadModel(.fatiguePredictor) else {
            return ruleResult
        }

        // Build an 8-feature vector from the rule-based trend summary.
        // These are "meta-features" derived from the raw time-series:
        //
        //  0: postureTrendSlope     — negative = posture degrading
        //  1: postureTrendR2        — how consistent the degradation is
        //  2: postureVariabilitySD  — increased variability = fatigue
        //  3: cadenceTrendSlope     — positive or negative change
        //  4: speedTrendSlope       — negative = slowing
        //  5: forwardLeanTrendSlope — positive = increasing lean
        //  6: lateralSwayTrendSlope — positive = increasing sway
        //  7: ruleBasedFatigueIndex — the rule-based composite (gives ML a baseline)
        let features: [Double?] = [
            ruleResult.postureTrendSlope,
            ruleResult.postureTrendR2,
            ruleResult.postureVariabilitySD,
            ruleResult.cadenceTrendSlope,
            ruleResult.speedTrendSlope,
            ruleResult.forwardLeanTrendSlope,
            ruleResult.lateralSwayTrendSlope,
            ruleResult.fatigueIndex
        ]

        guard let featureArray = MLModelService.makeFeatureArray(features) else {
            logger.warning("Failed to create feature array — using rule-based result")
            return ruleResult
        }

        do {
            let input = try MLDictionaryFeatureProvider(
                dictionary: ["features": MLFeatureValue(multiArray: featureArray)]
            )
            let prediction = try model.prediction(from: input)

            // Extract ML fatigue index
            let mlFatigueIndex: Double
            if let idx = prediction.featureValue(for: "fatigueIndex")?.doubleValue {
                mlFatigueIndex = min(100, max(0, idx))
            } else {
                mlFatigueIndex = ruleResult.fatigueIndex
            }

            // Extract ML isFatigued classification
            let mlIsFatigued: Bool
            if let label = prediction.featureValue(for: "isFatigued")?.stringValue {
                mlIsFatigued = label == "true" || label == "1" || label == "yes"
            } else {
                // Derive from ML fatigue index
                mlIsFatigued = mlFatigueIndex > 25
            }

            logger.debug("Fatigue ML — index: \(mlFatigueIndex, format: .fixed(precision: 1)), fatigued: \(mlIsFatigued)")

            // Rebuild the assessment with ML predictions but keep all
            // the trend detail from the rule-based analyzer (interpretability).
            return FatigueAssessment(
                fatigueIndex: mlFatigueIndex,
                postureVariabilitySD: ruleResult.postureVariabilitySD,
                postureTrendSlope: ruleResult.postureTrendSlope,
                postureTrendR2: ruleResult.postureTrendR2,
                cadenceTrendSlope: ruleResult.cadenceTrendSlope,
                speedTrendSlope: ruleResult.speedTrendSlope,
                forwardLeanTrendSlope: ruleResult.forwardLeanTrendSlope,
                lateralSwayTrendSlope: ruleResult.lateralSwayTrendSlope,
                isFatigued: mlIsFatigued
            )
        } catch {
            logger.error("Fatigue prediction failed: \(error.localizedDescription)")
            return ruleResult
        }
    }

    func reset() {
        fallback.reset()
    }
}
