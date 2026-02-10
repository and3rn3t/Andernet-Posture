//
//  CoreMLPostureAnalyzer.swift
//  Andernet Posture
//
//  CoreML-augmented posture analyzer. Uses the DefaultPostureAnalyzer
//  for geometric feature extraction (angles, CVA, SVA, etc.) then
//  optionally replaces the composite-score computation and Kendall
//  classification with a trained CoreML model.
//
//  This is an *augmentation* pattern — geometric metrics stay rule-based
//  (clinically validated trigonometry), while the subjective scoring
//  and classification are learned from data.
//

import Foundation
import CoreML
import simd
import os.log

private let logger = AppLogger.ml

final class CoreMLPostureAnalyzer: PostureAnalyzer {

    private let modelService: MLModelService
    private let geometric = DefaultPostureAnalyzer()

    init(modelService: MLModelService) {
        self.modelService = modelService
    }

    // MARK: - PostureAnalyzer Protocol

    func analyze(joints: [JointName: SIMD3<Float>]) -> PostureMetrics? {
        // Always use geometric analyzer for feature extraction
        guard let metrics = geometric.analyze(joints: joints) else {
            return nil
        }

        // If ML is disabled or model unavailable, return geometric results as-is
        guard modelService.useMLModels,
              let model = modelService.loadModel(.postureScorer) else {
            return metrics
        }

        // Build feature vector from the 9 sub-component scores
        // These are the clinically meaningful intermediate features
        let subScores: [Double?] = [
            normalizeAngle(metrics.craniovertebralAngleDeg, ideal: 52, maxDev: 20),  // CVA
            normalizeSVA(metrics.sagittalVerticalAxisCm),                             // SVA
            normalizeAngle(metrics.sagittalTrunkLeanDeg, ideal: 0, maxDev: 15),      // trunk lean
            normalizeAngle(metrics.frontalTrunkLeanDeg, ideal: 0, maxDev: 10),       // lateral lean
            normalizeDistance(metrics.shoulderAsymmetryCm, maxDev: 5),               // shoulder
            normalizeAngle(metrics.thoracicKyphosisDeg, ideal: 35, maxDev: 25),      // kyphosis
            normalizeAngle(metrics.pelvicObliquityDeg, ideal: 0, maxDev: 8),         // pelvic
            normalizeAngle(metrics.lumbarLordosisDeg, ideal: 45, maxDev: 25),        // lordosis
            normalizeDistance(metrics.coronalSpineDeviationCm, maxDev: 4)             // coronal
        ]

        guard let inputArray = MLModelService.makeFeatureArray(subScores) else {
            return metrics
        }

        do {
            let provider = try MLDictionaryFeatureProvider(
                dictionary: ["features": MLFeatureValue(multiArray: inputArray)]
            )
            let prediction = try model.prediction(from: provider)

            // Extract ML-predicted composite score (0–100)
            let mlScore: Double
            if let scoreValue = prediction.featureValue(for: "postureScore")?.doubleValue {
                mlScore = max(0, min(100, scoreValue))
            } else {
                mlScore = metrics.postureScore
            }

            // Extract ML-predicted Kendall type if available
            let mlKendall: PosturalType
            if let typeStr = prediction.featureValue(for: "posturalType")?.stringValue,
               let parsed = PosturalType(rawValue: typeStr) {
                mlKendall = parsed
            } else {
                mlKendall = metrics.posturalType
            }

            // Rebuild metrics with ML-predicted score and type,
            // keeping all geometric measurements intact
            return PostureMetrics(
                sagittalTrunkLeanDeg: metrics.sagittalTrunkLeanDeg,
                frontalTrunkLeanDeg: metrics.frontalTrunkLeanDeg,
                craniovertebralAngleDeg: metrics.craniovertebralAngleDeg,
                sagittalVerticalAxisCm: metrics.sagittalVerticalAxisCm,
                shoulderAsymmetryCm: metrics.shoulderAsymmetryCm,
                shoulderTiltDeg: metrics.shoulderTiltDeg,
                pelvicObliquityDeg: metrics.pelvicObliquityDeg,
                thoracicKyphosisDeg: metrics.thoracicKyphosisDeg,
                lumbarLordosisDeg: metrics.lumbarLordosisDeg,
                coronalSpineDeviationCm: metrics.coronalSpineDeviationCm,
                posturalType: mlKendall,
                nyprScore: metrics.nyprScore,
                nyprMaxScore: metrics.nyprMaxScore,
                postureScore: mlScore,
                severities: metrics.severities
            )
        } catch {
            logger.error("CoreML posture prediction failed: \(error.localizedDescription)")
            return metrics
        }
    }

    func computeSessionScore(trunkLeans: [Double], lateralLeans: [Double]) -> Double {
        // Session-level scoring stays rule-based (simple weighted average)
        geometric.computeSessionScore(trunkLeans: trunkLeans, lateralLeans: lateralLeans)
    }

    // MARK: - Feature Normalization

    /// Normalize an angle measurement to 0–100 score (100 = ideal).
    private func normalizeAngle(_ value: Double, ideal: Double, maxDev: Double) -> Double {
        let deviation = abs(value - ideal)
        return max(0, min(100, (1.0 - deviation / maxDev) * 100))
    }

    /// Normalize SVA to 0–100 score (0 cm = 100, ≥8 cm = 0).
    private func normalizeSVA(_ cm: Double) -> Double {
        max(0, min(100, (1.0 - abs(cm) / 8.0) * 100))
    }

    /// Normalize a distance deviation to 0–100 score.
    private func normalizeDistance(_ cm: Double, maxDev: Double) -> Double {
        max(0, min(100, (1.0 - abs(cm) / maxDev) * 100))
    }
}
