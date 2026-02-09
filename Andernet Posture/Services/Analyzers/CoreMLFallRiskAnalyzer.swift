//
//  CoreMLFallRiskAnalyzer.swift
//  Andernet Posture
//
//  CoreML-backed fall risk predictor. Conforms to the existing
//  FallRiskAnalyzer protocol. Falls back to DefaultFallRiskAnalyzer
//  when the model isn't available.
//
//  The ML model can capture non-linear interactions between risk
//  factors (e.g., low speed + high stride variability is worse than
//  either alone) that the linear weighted sum cannot.
//

import Foundation
import CoreML
import os.log

private let logger = Logger(subsystem: "dev.andernet.posture", category: "ML.FallRisk")

final class CoreMLFallRiskAnalyzer: FallRiskAnalyzer {

    private let modelService: MLModelService
    private let fallback = DefaultFallRiskAnalyzer()

    init(modelService: MLModelService) {
        self.modelService = modelService
    }

    // MARK: - FallRiskAnalyzer Protocol

    func assess(
        walkingSpeedMPS: Double?,
        strideTimeCVPercent: Double?,
        doubleSupportPercent: Double?,
        stepWidthVariabilityCm: Double?,
        swayVelocityMMS: Double?,
        stepAsymmetryPercent: Double?,
        tugTimeSec: Double?,
        footClearanceM: Double?
    ) -> FallRiskAssessment {

        guard modelService.useMLModels,
              let model = modelService.loadModel(.fallRiskPredictor) else {
            return fallback.assess(
                walkingSpeedMPS: walkingSpeedMPS,
                strideTimeCVPercent: strideTimeCVPercent,
                doubleSupportPercent: doubleSupportPercent,
                stepWidthVariabilityCm: stepWidthVariabilityCm,
                swayVelocityMMS: swayVelocityMMS,
                stepAsymmetryPercent: stepAsymmetryPercent,
                tugTimeSec: tugTimeSec,
                footClearanceM: footClearanceM
            )
        }

        // Build feature vector (8 features, sentinel = −1 for missing)
        let features: [Double?] = [
            walkingSpeedMPS,
            strideTimeCVPercent,
            doubleSupportPercent,
            stepWidthVariabilityCm,
            swayVelocityMMS,
            stepAsymmetryPercent,
            tugTimeSec,
            footClearanceM
        ]

        guard let inputArray = MLModelService.makeFeatureArray(features) else {
            logger.warning("Failed to build feature array; falling back to rules.")
            return fallbackAssess(features: features)
        }

        do {
            let provider = try MLDictionaryFeatureProvider(
                dictionary: ["features": MLFeatureValue(multiArray: inputArray)]
            )
            let prediction = try model.prediction(from: provider)
            return parsePrediction(prediction, features: features)
        } catch {
            logger.error("CoreML fall risk prediction failed: \(error.localizedDescription)")
            return fallbackAssess(features: features)
        }
    }

    // MARK: - Prediction Parsing

    private func parsePrediction(
        _ prediction: MLFeatureProvider,
        features: [Double?]
    ) -> FallRiskAssessment {

        // Extract composite score
        let mlScore: Double
        if let score = prediction.featureValue(for: "compositeScore")?.doubleValue {
            mlScore = max(0, min(100, score))
        } else {
            mlScore = 0
        }

        // Extract risk level
        let mlLevel: FallRiskLevel
        if let levelStr = prediction.featureValue(for: "riskLevel")?.stringValue,
           let parsed = FallRiskLevel(rawValue: levelStr) {
            mlLevel = parsed
        } else if mlScore >= 60 {
            mlLevel = .high
        } else if mlScore >= 30 {
            mlLevel = .moderate
        } else {
            mlLevel = .low
        }

        // Build factor breakdown using the rule-based analyzer
        // (for interpretability — the ML score may differ from
        // the sum of per-factor sub-scores, and that's expected)
        let ruleResult = fallback.assess(
            walkingSpeedMPS: features[0],
            strideTimeCVPercent: features[1],
            doubleSupportPercent: features[2],
            stepWidthVariabilityCm: features[3],
            swayVelocityMMS: features[4],
            stepAsymmetryPercent: features[5],
            tugTimeSec: features[6],
            footClearanceM: features[7]
        )

        return FallRiskAssessment(
            compositeScore: mlScore,
            riskLevel: mlLevel,
            factorBreakdown: ruleResult.factorBreakdown,
            riskFactorCount: ruleResult.riskFactorCount
        )
    }

    // MARK: - Fallback

    private func fallbackAssess(features: [Double?]) -> FallRiskAssessment {
        fallback.assess(
            walkingSpeedMPS: features[0],
            strideTimeCVPercent: features[1],
            doubleSupportPercent: features[2],
            stepWidthVariabilityCm: features[3],
            swayVelocityMMS: features[4],
            stepAsymmetryPercent: features[5],
            tugTimeSec: features[6],
            footClearanceM: features[7]
        )
    }
}
