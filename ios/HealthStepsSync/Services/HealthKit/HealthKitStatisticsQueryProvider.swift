//
//  StatisticsQueryProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation
import HealthKit

enum HealthKitQueryError: Error {
    case statisticIsNil
}

class HealthKitStatisticsQueryProvider: StatisticsQueryProvider {
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationStatus() -> HealthKitAuthStatus {
        guard isAvailable else {
            return .unavailable
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return .unavailable
        }

        let status = healthStore.authorizationStatus(for: stepType)

        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingAuthorized:
            return .authorized
        case .sharingDenied:
            return .denied
        @unknown default:
            return .notDetermined
        }
    }

    private let healthStore: HKHealthStore

    init() {
        self.healthStore = HKHealthStore()
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }

        let stepType = HKQuantityType(.stepCount)

        // We only need READ access, not write
        try await healthStore.requestAuthorization(
            toShare: [],
            read: [stepType]
        )
    }

    func getAggregatedStepCount(for interval: DateInterval) async throws -> AggregatedStepData {
        let stepType = HKQuantityType(.stepCount)

        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                }

                guard let statistics, let sum = statistics.sumQuantity() else {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: HealthKitQueryError.statisticIsNil))
                    return
                }
                let steps = Int(sum.doubleValue(for: .count()))

                let data = AggregatedStepData(count: steps, startDate: statistics.startDate, endDate: statistics.endDate)
                continuation.resume(returning: data)
            }

            self.healthStore.execute(query)
        }
    }
    private let anchorKey = "healthkit.anchor.steps"

    func saveAnchor(_ anchor: HKQueryAnchor?) {
        guard let anchor else { return }

        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: anchor,
                requiringSecureCoding: true
            )
            UserDefaults.standard.set(data, forKey: anchorKey)
        } catch {
            print("Failed to save anchor:", error)
        }
    }
    func loadAnchor() -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: anchorKey) else {
            return nil // First run → full sync
        }

        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClass: HKQueryAnchor.self,
                from: data
            )
        } catch {
            print("Failed to load anchor:", error)
            return nil
        }
    }

    func getRawStepSamples(for interval: DateInterval) async throws -> [StepSampleData] {
        let stepType = HKQuantityType(.stepCount)

        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )

        // Sort by start date for consistent ordering
        let batchSize = 10000
        var anchor: HKQueryAnchor? = loadAnchor()

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: stepType,
                predicate: predicate,
                anchor: anchor,
                limit: batchSize
            ) { [weak self] query, samples, deletedObjects, newAnchor, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                    return
                }

                anchor = newAnchor
                self?.saveAnchor(newAnchor)

                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                if quantitySamples.count == batchSize {
                    self?.healthStore.execute(query)
                }

                continuation.resume(returning: quantitySamples)
            }

            self.healthStore.execute(query)
        }
    }
}
