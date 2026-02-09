//
//  ClinicalTestProtocol.swift
//  Andernet Posture
//
//  Guided clinical test protocols for TUG, Romberg, and 6MWT.
//  Provides step-by-step instructions, timing, and automated analysis.
//

import Foundation
import Observation
import os.log

// MARK: - Test Protocol State

/// State of a clinical test protocol.
enum ClinicalTestState: Sendable {
    case notStarted
    case instructing(step: Int, totalSteps: Int, instruction: String)
    case countdown(seconds: Int)
    case running(phaseLabel: String)
    case transitioning(instruction: String)
    case completed
    case cancelled
}

// MARK: - Protocol ViewModel

/// Drives guided clinical test execution.
@Observable
final class ClinicalTestViewModel {

    // MARK: - State

    var testType: ClinicalTestType?
    var testState: ClinicalTestState = .notStarted
    var elapsedTime: TimeInterval = 0
    var phaseElapsedTime: TimeInterval = 0

    // TUG results
    var tugResult: TUGResult?

    // Romberg results
    var rombergResult: RombergResult?

    // 6MWT results
    var sixMWTResult: SixMinuteWalkResult?
    var sixMWTDistance: Double = 0

    // MARK: - Dependencies

    private let balanceAnalyzer: any BalanceAnalyzer
    private let cardioEstimator: any CardioEstimator
    private let healthKitService: any HealthKitService

    // MARK: - Private

    private var timer: Timer?
    private var testStartTime: Date?
    private var phaseStartTime: Date?
    private var currentStep = 0

    init(
        balanceAnalyzer: any BalanceAnalyzer = DefaultBalanceAnalyzer(),
        cardioEstimator: any CardioEstimator = DefaultCardioEstimator(),
        healthKitService: any HealthKitService = DefaultHealthKitService()
    ) {
        self.balanceAnalyzer = balanceAnalyzer
        self.cardioEstimator = cardioEstimator
        self.healthKitService = healthKitService
    }

    // MARK: - TUG Protocol

    /// Start Timed Up and Go test.
    /// Protocol: Sit → Stand → Walk 3m → Turn → Walk back → Sit
    func startTUG() {
        testType = .timedUpAndGo
        currentStep = 0
        let instructions = tugInstructions()
        testState = .instructing(step: 1, totalSteps: instructions.count, instruction: instructions[0])
    }

    /// Advance TUG to next step. Called by user tapping "Next" or automatically.
    func advanceTUG() {
        currentStep += 1
        let instructions = tugInstructions()

        if currentStep < instructions.count {
            testState = .instructing(step: currentStep + 1, totalSteps: instructions.count, instruction: instructions[currentStep])
        } else if currentStep == instructions.count {
            // Start countdown
            startCountdown {
                self.testStartTime = Date()
                self.testState = .running(phaseLabel: "Stand, walk 3m, turn, return, sit")
                self.startTimer()
            }
        }
    }

    /// Complete TUG test. Called when user indicates they've sat back down.
    func completeTUG(age: Int? = nil) {
        stopTimer()
        let timeSec = elapsedTime
        tugResult = cardioEstimator.evaluateTUG(timeSec: timeSec, age: age)
        testState = .completed
    }

    // MARK: - Romberg Protocol

    /// Start Romberg balance test.
    /// Protocol: 30s eyes open → 30s eyes closed → compare sway
    func startRomberg() {
        testType = .romberg
        currentStep = 0
        let instructions = rombergInstructions()
        testState = .instructing(step: 1, totalSteps: instructions.count, instruction: instructions[0])
    }

    func advanceRomberg() {
        currentStep += 1
        let instructions = rombergInstructions()

        if currentStep < instructions.count {
            testState = .instructing(step: currentStep + 1, totalSteps: instructions.count, instruction: instructions[currentStep])
        } else if currentStep == instructions.count {
            // Eyes open phase
            balanceAnalyzer.startRombergEyesOpen()
            startCountdown {
                self.testState = .running(phaseLabel: "Eyes Open — Stand Still (30s)")
                self.phaseStartTime = Date()
                self.startPhaseTimer(duration: 30) {
                    // Transition to eyes closed
                    self.balanceAnalyzer.startRombergEyesClosed()
                    self.testState = .transitioning(instruction: "Now close your eyes. Keep standing still.")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.testState = .running(phaseLabel: "Eyes Closed — Stand Still (30s)")
                        self.phaseStartTime = Date()
                        self.startPhaseTimer(duration: 30) {
                            // Complete
                            self.rombergResult = self.balanceAnalyzer.completeRomberg()
                            self.testState = .completed
                        }
                    }
                }
            }
        }
    }

    // MARK: - 6MWT Protocol

    /// Start 6-Minute Walk Test.
    func start6MWT() {
        testType = .sixMinuteWalk
        currentStep = 0
        sixMWTDistance = 0
        let instructions = sixMWTInstructions()
        testState = .instructing(step: 1, totalSteps: instructions.count, instruction: instructions[0])
    }

    func advance6MWT() {
        currentStep += 1
        let instructions = sixMWTInstructions()

        if currentStep < instructions.count {
            testState = .instructing(step: currentStep + 1, totalSteps: instructions.count, instruction: instructions[currentStep])
        } else if currentStep == instructions.count {
            startCountdown {
                self.testStartTime = Date()
                self.testState = .running(phaseLabel: "Walk at your normal pace (6 minutes)")
                self.startTimer()
                // Auto-complete after 6 minutes
                DispatchQueue.main.asyncAfter(deadline: .now() + 360) { [weak self] in
                    self?.complete6MWT()
                }
            }
        }
    }

    /// Update walking distance during 6MWT (from gait analyzer displacement tracking).
    func update6MWTDistance(_ distanceM: Double) {
        sixMWTDistance = distanceM
    }

    /// Complete 6MWT (auto or manual).
    func complete6MWT(age: Int? = nil, heightM: Double? = nil, weightKg: Double? = nil, sexIsMale: Bool? = nil) {
        stopTimer()
        sixMWTResult = cardioEstimator.evaluate6MWT(
            distanceM: sixMWTDistance,
            age: age,
            heightM: heightM,
            weightKg: weightKg,
            sexIsMale: sexIsMale
        )
        testState = .completed

        // Save 6MWT distance to HealthKit
        if UserDefaults.standard.bool(forKey: "healthKitSync"), sixMWTDistance > 0 {
            let hkService = healthKitService
            let distance = sixMWTDistance
            Task {
                do {
                    try await hkService.saveSixMWTDistance(distance, date: Date())
                } catch {
                    AppLogger.healthKit.error("Failed to save 6MWT to HealthKit: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Cancel

    func cancelTest() {
        stopTimer()
        testState = .cancelled
        balanceAnalyzer.reset()
    }

    // MARK: - Private Instructions

    private func tugInstructions() -> [String] {
        [
            "Sit in a standard chair with your back against the chair, arms resting on the armrests.",
            "Place the device where the camera can see your full body. You'll need about 3 meters of clear walking space.",
            "When the timer starts:\n1. Stand up from the chair\n2. Walk 3 meters at your normal pace\n3. Turn around\n4. Walk back to the chair\n5. Sit down",
            "Tap 'Start' when ready. Tap 'Done' when you're seated again."
        ]
    }

    private func rombergInstructions() -> [String] {
        [
            "Stand with feet together, arms at your sides.",
            "Place the device where the camera can see your full body while standing.",
            "The test has two phases:\n• Phase 1: Stand still with eyes OPEN for 30 seconds\n• Phase 2: Stand still with eyes CLOSED for 30 seconds",
            "Tap 'Start' when ready. Follow the audio/visual prompts for each phase."
        ]
    }

    private func sixMWTInstructions() -> [String] {
        [
            "You will walk at your normal pace for 6 minutes.",
            "Walk back and forth along a flat, unobstructed hallway (at least 20 meters is ideal).",
            "Walk at your own pace. You may slow down or stop to rest if needed, but resume walking as soon as you can.",
            "Place the device where the camera can track you. Tap 'Start' when ready."
        ]
    }

    // MARK: - Timer Helpers

    private func startCountdown(completion: @escaping () -> Void) {
        var remaining = 3
        testState = .countdown(seconds: remaining)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            remaining -= 1
            if remaining <= 0 {
                t.invalidate()
                completion()
            } else {
                self?.testState = .countdown(seconds: remaining)
            }
        }
    }

    private func startTimer() {
        testStartTime = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let start = self?.testStartTime else { return }
            self?.elapsedTime = Date().timeIntervalSince(start)
        }
    }

    private func startPhaseTimer(duration: TimeInterval, completion: @escaping () -> Void) {
        var elapsed: TimeInterval = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
            elapsed += 0.5
            self?.phaseElapsedTime = elapsed
            if elapsed >= duration {
                t.invalidate()
                completion()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
