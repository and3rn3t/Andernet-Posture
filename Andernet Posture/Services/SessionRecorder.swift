//
//  SessionRecorder.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import Foundation
import simd

/// Recording state machine states.
enum RecordingState: Sendable {
    case idle
    case calibrating
    case recording
    case paused
    case finished
}

/// Protocol for session recording — collects time-series frames + step events.
protocol SessionRecorder {
    var state: RecordingState { get }
    var elapsedTime: TimeInterval { get }
    var frameCount: Int { get }
    var stepCount: Int { get }

    func startCalibration()
    func startRecording()
    func pause()
    func resume()
    func stop()
    func reset()

    /// Record a body frame with joint positions + computed metrics.
    func recordFrame(_ frame: BodyFrame)

    /// Record a detected step event.
    func recordStep(_ step: StepEvent)

    /// Record a CoreMotion frame.
    func recordMotionFrame(_ frame: MotionFrame)

    /// Retrieve collected frames.
    func collectedFrames() -> [BodyFrame]

    /// Retrieve collected step events.
    func collectedSteps() -> [StepEvent]

    /// Retrieve collected motion frames.
    func collectedMotionFrames() -> [MotionFrame]
}

// MARK: - Default Implementation

final class DefaultSessionRecorder: SessionRecorder {

    private(set) var state: RecordingState = .idle

    private var startDate: Date?
    private var pauseDate: Date?
    private var accumulatedPause: TimeInterval = 0

    private var frames: [BodyFrame] = []
    private var steps: [StepEvent] = []
    private var motionFrames: [MotionFrame] = []

    var elapsedTime: TimeInterval {
        guard let start = startDate else { return 0 }
        switch state {
        case .recording:
            return Date().timeIntervalSince(start) - accumulatedPause
        case .paused:
            let pauseStart = pauseDate ?? Date()
            return pauseStart.timeIntervalSince(start) - accumulatedPause
        case .finished:
            return (pauseDate ?? Date()).timeIntervalSince(start) - accumulatedPause
        default:
            return 0
        }
    }

    var frameCount: Int { frames.count }
    var stepCount: Int { steps.count }

    // MARK: State transitions

    func startCalibration() {
        guard state == .idle else { return }
        state = .calibrating
    }

    func startRecording() {
        guard state == .calibrating || state == .idle else { return }
        state = .recording
        startDate = Date()
        accumulatedPause = 0
    }

    func pause() {
        guard state == .recording else { return }
        state = .paused
        pauseDate = Date()
    }

    func resume() {
        guard state == .paused, let pd = pauseDate else { return }
        accumulatedPause += Date().timeIntervalSince(pd)
        pauseDate = nil
        state = .recording
    }

    func stop() {
        guard state == .recording || state == .paused else { return }
        if state == .recording {
            pauseDate = Date()
        }
        state = .finished
    }

    func reset() {
        state = .idle
        startDate = nil
        pauseDate = nil
        accumulatedPause = 0
        frames.removeAll()
        steps.removeAll()
        motionFrames.removeAll()
    }

    // MARK: Data collection

    func recordFrame(_ frame: BodyFrame) {
        guard state == .recording else { return }
        frames.append(frame)
    }

    func recordStep(_ step: StepEvent) {
        guard state == .recording else { return }
        steps.append(step)
    }

    func recordMotionFrame(_ frame: MotionFrame) {
        guard state == .recording else { return }
        motionFrames.append(frame)
    }

    func collectedFrames() -> [BodyFrame] { frames }
    func collectedSteps() -> [StepEvent] { steps }
    func collectedMotionFrames() -> [MotionFrame] { motionFrames }
}
