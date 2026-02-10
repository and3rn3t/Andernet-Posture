//
//  CoreMLCrossedSyndromeDetector.swift
//  Andernet Posture
//
//  CoreML-backed crossed syndrome detector. Conforms to the existing
//  CrossedSyndromeDetector protocol. Falls back to
//  DefaultCrossedSyndromeDetector when the model isn't available.
//
//  The ML model can capture interaction effects between upper and
//  lower body deviations — e.g., kyphosis + anterior pelvic tilt
//  co-occurring is more significant than either alone, and threshold-
//  based rules miss these non-linear interactions.
//
//  Model architecture (when trained):
//  - Input:  7-feature vector (angles/distances, sentinel −1 for nil)
//  - Output: upperCrossedScore (0–100), lowerCrossedScore (0–100)
//  - Type:   Multi-output regression (tabular)
//

import Foundation
import CoreML
import os.log

private let logger = AppLogger.ml

final class CoreMLCrossedSyndromeDetector: CrossedSyndromeDetector {

    private let modelService: MLModelService
    private let fallback = DefaultCrossedSyndromeDetector()

    init(modelService: MLModelService) {
        self.modelService = modelService
    }

    // MARK: - CrossedSyndromeDetector Protocol

    func detect(
        craniovertebralAngleDeg: Double,
        shoulderProtractionCm: Double,
        thoracicKyphosisDeg: Double,
        cervicalLordosisDeg: Double?,
        pelvicTiltDeg: Double,
        lumbarLordosisDeg: Double,
        hipFlexionRestDeg: Double?
    ) -> CrossedSyndromeResult {

        guard modelService.useMLModels,
              let model = modelService.loadModel(.crossedSyndromeDetector) else {
            return fallback.detect(
                craniovertebralAngleDeg: craniovertebralAngleDeg,
                shoulderProtractionCm: shoulderProtractionCm,
                thoracicKyphosisDeg: thoracicKyphosisDeg,
                cervicalLordosisDeg: cervicalLordosisDeg,
                pelvicTiltDeg: pelvicTiltDeg,
                lumbarLordosisDeg: lumbarLordosisDeg,
                hipFlexionRestDeg: hipFlexionRestDeg
            )
        }

        // Build 7-feature vector (sentinel = −1 for missing optional values)
        let features: [Double?] = [
            craniovertebralAngleDeg,
            shoulderProtractionCm,
            thoracicKyphosisDeg,
            cervicalLordosisDeg,      // optional
            pelvicTiltDeg,
            lumbarLordosisDeg,
            hipFlexionRestDeg          // optional
        ]

        guard let featureArray = MLModelService.makeFeatureArray(features) else {
            logger.warning("Failed to create feature array — falling back to rules")
            return fallback.detect(
                craniovertebralAngleDeg: craniovertebralAngleDeg,
                shoulderProtractionCm: shoulderProtractionCm,
                thoracicKyphosisDeg: thoracicKyphosisDeg,
                cervicalLordosisDeg: cervicalLordosisDeg,
                pelvicTiltDeg: pelvicTiltDeg,
                lumbarLordosisDeg: lumbarLordosisDeg,
                hipFlexionRestDeg: hipFlexionRestDeg
            )
        }

        do {
            let input = try MLDictionaryFeatureProvider(
                dictionary: ["features": MLFeatureValue(multiArray: featureArray)]
            )
            let prediction = try model.prediction(from: input)

            // Extract predicted scores
            let mlUpperScore = clampScore(prediction, key: "upperCrossedScore")
            let mlLowerScore = clampScore(prediction, key: "lowerCrossedScore")

            // Use rule-based detector for factor breakdown (interpretability)
            let ruleResult = fallback.detect(
                craniovertebralAngleDeg: craniovertebralAngleDeg,
                shoulderProtractionCm: shoulderProtractionCm,
                thoracicKyphosisDeg: thoracicKyphosisDeg,
                cervicalLordosisDeg: cervicalLordosisDeg,
                pelvicTiltDeg: pelvicTiltDeg,
                lumbarLordosisDeg: lumbarLordosisDeg,
                hipFlexionRestDeg: hipFlexionRestDeg
            )

            // Determine syndromes from ML scores
            var syndromes: [CrossedSyndromeType] = []
            if mlUpperScore >= 40 { syndromes.append(.upperCrossed) }
            if mlLowerScore >= 40 { syndromes.append(.lowerCrossed) }

            logger.debug("CrossedSyndrome ML — upper: \(mlUpperScore, format: .fixed(precision: 1)), lower: \(mlLowerScore, format: .fixed(precision: 1))")

            return CrossedSyndromeResult(
                upperCrossedScore: mlUpperScore,
                lowerCrossedScore: mlLowerScore,
                detectedSyndromes: syndromes,
                upperFactors: ruleResult.upperFactors,
                lowerFactors: ruleResult.lowerFactors
            )
        } catch {
            logger.error("CrossedSyndrome prediction failed: \(error.localizedDescription)")
            return fallback.detect(
                craniovertebralAngleDeg: craniovertebralAngleDeg,
                shoulderProtractionCm: shoulderProtractionCm,
                thoracicKyphosisDeg: thoracicKyphosisDeg,
                cervicalLordosisDeg: cervicalLordosisDeg,
                pelvicTiltDeg: pelvicTiltDeg,
                lumbarLordosisDeg: lumbarLordosisDeg,
                hipFlexionRestDeg: hipFlexionRestDeg
            )
        }
    }

    // MARK: - Helpers

    /// Extract a Double score from the prediction output, clamped to 0–100.
    private func clampScore(_ prediction: MLFeatureProvider, key: String) -> Double {
        guard let value = prediction.featureValue(for: key)?.doubleValue else {
            return 0
        }
        return min(100, max(0, value))
    }
}
