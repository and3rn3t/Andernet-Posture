//
//  HealthKitService.swift
//  Andernet Posture
//
//  Created by Matt on 2/8/26.
//

import Foundation
import HealthKit

/// Protocol for HealthKit integration.
protocol HealthKitService {
    var isAvailable: Bool { get }

    /// Request authorization to read/write relevant HealthKit data types.
    func requestAuthorization() async throws

    /// Write session metrics to HealthKit.
    func saveSession(
        steps: Int,
        walkingSpeed: Double?,    // m/s
        strideLength: Double?,    // m
        asymmetry: Double?,       // 0–1 (percentage / 100)
        start: Date,
        end: Date
    ) async throws

    /// Read step count for a date range.
    func fetchSteps(from start: Date, to end: Date) async throws -> Double

    /// Read walking speed samples for a date range.
    func fetchWalkingSpeed(from start: Date, to end: Date) async throws -> [HKQuantitySample]
}

// MARK: - Default Implementation

final class DefaultHealthKitService: HealthKitService {

    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: Shared types

    private var readTypes: Set<HKObjectType> {
        let types: [HKQuantityType] = [
            .init(.stepCount),
            .init(.walkingSpeed),
            .init(.walkingStepLength),
            .init(.walkingAsymmetryPercentage)
        ]
        return Set(types)
    }

    private var writeTypes: Set<HKSampleType> {
        let types: [HKQuantityType] = [
            .init(.stepCount),
            .init(.walkingSpeed),
            .init(.walkingStepLength)
        ]
        return Set(types)
    }

    // MARK: Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    // MARK: Write

    func saveSession(
        steps: Int,
        walkingSpeed: Double?,
        strideLength: Double?,
        asymmetry: Double?,
        start: Date,
        end: Date
    ) async throws {
        var samples: [HKQuantitySample] = []

        if steps > 0 {
            let qty = HKQuantity(unit: .count(), doubleValue: Double(steps))
            samples.append(HKQuantitySample(type: .init(.stepCount), quantity: qty, start: start, end: end))
        }

        if let speed = walkingSpeed, speed > 0 {
            let qty = HKQuantity(unit: HKUnit.meter().unitDivided(by: .second()), doubleValue: speed)
            samples.append(HKQuantitySample(type: .init(.walkingSpeed), quantity: qty, start: start, end: end))
        }

        if let stride = strideLength, stride > 0 {
            let qty = HKQuantity(unit: .meter(), doubleValue: stride)
            samples.append(HKQuantitySample(type: .init(.walkingStepLength), quantity: qty, start: start, end: end))
        }

        guard !samples.isEmpty else { return }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            store.save(samples) { success, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
    }

    // MARK: Read

    func fetchSteps(from start: Date, to end: Date) async throws -> Double {
        let type = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error { cont.resume(throwing: error); return }
                let sum = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: sum)
            }
            store.execute(query)
        }
    }

    func fetchWalkingSpeed(from start: Date, to end: Date) async throws -> [HKQuantitySample] {
        let type = HKQuantityType(.walkingSpeed)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }
}
