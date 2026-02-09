//
//  CoreMLGaitPatternClassifier.swift
//  Andernet Posture
//
//  CoreML-backed gait pattern classifier. Conforms to the existing
//  GaitPatternClassifier protocol so it drops into CaptureViewModel
//  via dependency injection with zero call-site changes.
//
//  When the .mlmodelc bundle is present the model runs inference;
//  otherwise it falls back to the rule-based DefaultGaitPatternClassifier.
//

import Foundation
import CoreML
import os.log

private let logger = Logger(subsystem: "dev.andernet.posture", category: "ML.GaitPattern")

final class CoreMLGaitPatternClassifier: GaitPatternClassifier {

    private let modelService: MLModelService
    private let fallback = DefaultGaitPatternClassifier()

    init(modelService: MLModelService) {
        self.modelService = modelService
    }

    // MARK: - GaitPatternClassifier Protocol

    // swiftlint:disable:next function_parameter_count
    func classify(
        stanceTimeLeftPercent: Double?,
        stanceTimeRightPercent: Double?,
        stepLengthLeftM: Double?,
        stepLengthRightM: Double?,
        cadenceSPM: Double?,
        avgStepWidthCm: Double?,
        stepWidthVariabilityCm: Double?,
        pelvicObliquityDeg: Double?,
        strideTimeCVPercent: Double?,
        walkingSpeedMPS: Double?,
        strideLengthM: Double?,
        hipFlexionROMDeg: Double?,
        armSwingAsymmetryPercent: Double?,
        kneeFlexionROMDeg: Double?
    ) -> GaitPatternResult {

        // Attempt CoreML prediction
        guard modelService.useMLModels,
              let model = modelService.loadModel(.gaitPatternClassifier) else {
            return fallback.classify(
                stanceTimeLeftPercent: stanceTimeLeftPercent,
                stanceTimeRightPercent: stanceTimeRightPercent,
                stepLengthLeftM: stepLengthLeftM,
                stepLengthRightM: stepLengthRightM,
                cadenceSPM: cadenceSPM,
                avgStepWidthCm: avgStepWidthCm,
                stepWidthVariabilityCm: stepWidthVariabilityCm,
                pelvicObliquityDeg: pelvicObliquityDeg,
                strideTimeCVPercent: strideTimeCVPercent,
                walkingSpeedMPS: walkingSpeedMPS,
                strideLengthM: strideLengthM,
                hipFlexionROMDeg: hipFlexionROMDeg,
                armSwingAsymmetryPercent: armSwingAsymmetryPercent,
                kneeFlexionROMDeg: kneeFlexionROMDeg
            )
        }

        // Build feature vector (14 features, sentinel = −1 for missing)
        let features: [Double?] = [
            stanceTimeLeftPercent,
            stanceTimeRightPercent,
            stepLengthLeftM,
            stepLengthRightM,
            cadenceSPM,
            avgStepWidthCm,
            stepWidthVariabilityCm,
            pelvicObliquityDeg,
            strideTimeCVPercent,
            walkingSpeedMPS,
            strideLengthM,
            hipFlexionROMDeg,
            armSwingAsymmetryPercent,
            kneeFlexionROMDeg
        ]

        guard let inputArray = MLModelService.makeFeatureArray(features) else {
            logger.warning("Failed to build feature array; falling back to rules.")
            return fallbackClassify(features: features)
        }

        do {
            let provider = try MLDictionaryFeatureProvider(
                dictionary: ["features": MLFeatureValue(multiArray: inputArray)]
            )
            let prediction = try model.prediction(from: provider)
            return parsePrediction(prediction)
        } catch {
            logger.error("CoreML prediction failed: \(error.localizedDescription)")
            return fallbackClassify(features: features)
        }
    }

    // MARK: - Prediction Parsing

    /// Parse the model output into a GaitPatternResult.
    /// Expected outputs: "label" (String) and "classProbability" (Dictionary).
    private func parsePrediction(_ prediction: MLFeatureProvider) -> GaitPatternResult {
        // Try to get class probabilities dictionary
        var scores: [GaitPatternType: Double] = [:]
        if let probDict = prediction.featureValue(for: "classProbability")?.dictionaryValue {
            for (key, value) in probDict {
                if let keyStr = key as? String,
                   let pattern = GaitPatternType(rawValue: keyStr),
                   let prob = value as? Double {
                    scores[pattern] = prob
                }
            }
        }

        // Get predicted label
        let labelStr = prediction.featureValue(for: "label")?.stringValue ?? "normal"
        let primary = GaitPatternType(rawValue: labelStr) ?? .normal
        let confidence = scores[primary] ?? 1.0

        // Fill missing patterns with 0
        for pattern in [GaitPatternType.normal, .antalgic, .trendelenburg, .festinating,
                        .circumduction, .ataxic, .waddling, .stiffKnee] where scores[pattern] == nil {
            scores[pattern] = 0.0
        }

        return GaitPatternResult(
            primaryPattern: primary,
            confidence: confidence,
            patternScores: scores,
            flags: ["CoreML v\(modelService.modelStatuses.first { $0.identifier == .gaitPatternClassifier }?.version ?? "?")"]
        )
    }

    // MARK: - Fallback

    private func fallbackClassify(features: [Double?]) -> GaitPatternResult {
        fallback.classify(
            stanceTimeLeftPercent: features[0],
            stanceTimeRightPercent: features[1],
            stepLengthLeftM: features[2],
            stepLengthRightM: features[3],
            cadenceSPM: features[4],
            avgStepWidthCm: features[5],
            stepWidthVariabilityCm: features[6],
            pelvicObliquityDeg: features[7],
            strideTimeCVPercent: features[8],
            walkingSpeedMPS: features[9],
            strideLengthM: features[10],
            hipFlexionROMDeg: features[11],
            armSwingAsymmetryPercent: features[12],
            kneeFlexionROMDeg: features[13]
        )
    }
}
