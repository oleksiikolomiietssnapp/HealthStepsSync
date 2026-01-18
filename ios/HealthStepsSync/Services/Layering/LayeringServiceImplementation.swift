//
//  LayeringServiceImplementation.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation
import OSLog

import Foundation

@MainActor
final class LayeringServiceImplementation: LayeringService {

    private(set) var maxStepsPerInterval = 10_000
    private let maxYearsBack = 10
    private let bucketMinutes = 15

    private let stepDataSource: StepDataSource
    private let storageProvider: LocalStorageProvider

    init(
        stepDataSource: StepDataSource,
        storageProvider: LocalStorageProvider
    ) {
        self.stepDataSource = stepDataSource
        self.storageProvider = storageProvider
    }

    @discardableResult
    func performLayering() async throws -> [SyncInterval] {
        // 1. Clear existing intervals
        try await clearAllIntervals()

        // 2. Define max range
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .year, value: -maxYearsBack, to: endDate) else {
            return []
        }

        // 3. Fetch step buckets once
        let buckets = try await stepDataSource.fetchStepBuckets(from: startDate, to: endDate, bucketMinutes: bucketMinutes)

        guard !buckets.isEmpty else {
            let interval = SyncInterval(startDate: startDate, endDate: endDate, stepCount: 0)
            try await storageProvider.insertInterval(
                startDate: interval.startDate,
                endDate: interval.endDate,
                stepCount: interval.stepCount
            )
            try storageProvider.save()
            return [interval]
        }

        // 4. Build balanced intervals
        let intervals = buildBalancedIntervals(buckets: buckets, targetSteps: maxStepsPerInterval)

        // 5. Save intervals
        for interval in intervals {
            try await storageProvider.insertInterval(
                startDate: interval.startDate,
                endDate: interval.endDate,
                stepCount: interval.stepCount
            )
        }
        try storageProvider.save()

        return intervals
    }

    func clearAllIntervals() async throws {
        try storageProvider.deleteIntervals()
        try storageProvider.save()
    }

    // MARK: - Greedy Backward Chunking
    private func buildBalancedIntervals(buckets: [StepBucket], targetSteps: Int) -> [SyncInterval] {
        var result: [SyncInterval] = []
        var endIndex = buckets.count - 1

        while endIndex >= 0 {
            var sum = 0
            var startIndex = endIndex

            while startIndex >= 0 && sum < targetSteps {
                sum += buckets[startIndex].steps
                startIndex -= 1
            }

            let candidate = startIndex + 1
            let prevCandidate = candidate + 1

            // Optional: choose closest fit to targetSteps
            if prevCandidate <= endIndex {
                let under = sum - buckets[candidate].steps
                let over = sum
                if abs(under - targetSteps) < abs(over - targetSteps) {
                    startIndex += 1
                    sum = under
                }
            }

            let interval = SyncInterval(
                startDate: buckets[startIndex + 1].start,
                endDate: buckets[endIndex].end,
                stepCount: sum
            )
            result.append(interval)

            endIndex = startIndex
        }

        return result.reversed()
    }
}
