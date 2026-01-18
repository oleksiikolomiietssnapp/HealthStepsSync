//
//  LayeringServiceImplementation.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation
import OSLog

@MainActor
final class LayeringServiceImplementation: LayeringService {
    private(set) var maxStepsPerInterval = 10_000
    private let maxYearsBack = 10
    private let minIntervalDuration: TimeInterval = 1800

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
        let startDate = Calendar.current.date(byAdding: .year, value: -maxYearsBack, to: endDate)!

        // 3. Check if any data exists
        let fullInterval = DateInterval(start: startDate, end: endDate)
        let totalStepsData = try await stepDataSource.getAggregatedStepData(for: fullInterval)

        guard totalStepsData.count > 0 else {
            let interval = SyncInterval(startDate: startDate, endDate: endDate, stepCount: 0)
            storageProvider.insertInterval(interval)
            try storageProvider.save()
            return [interval]
        }

        // 4. Use actual data boundaries
        let actualStart = totalStepsData.startDate
        let actualEnd = totalStepsData.endDate

        // 5. Perform greedy backward chunking
        let intervals = try await greedyBackwardChunks(
            from: actualStart,
            to: actualEnd,
            targetSteps: maxStepsPerInterval
        )

        print("Layering done: \(intervals.count) intervals")

        // 6. Save all intervals
        for interval in intervals {
            storageProvider.insertInterval(interval)
        }

        // Saving right away slows the process
        // System will save it when with delay and with no UI issue.
        // try storageProvider.save()

        return intervals
    }

    func clearAllIntervals() async throws {
        try storageProvider.deleteIntervals()
        try storageProvider.save()
    }

    // MARK: - Greedy Backward Algorithm

    private func greedyBackwardChunks(
        from start: Date,
        to end: Date,
        targetSteps: Int
    ) async throws -> [SyncInterval] {

        var intervals: [SyncInterval] = []
        var currentEnd = end
        var iterationCount = 0
        let maxIterations = Int(
            end.timeIntervalSince(start) / 3600
        )

        while currentEnd > start && iterationCount < maxIterations {
            iterationCount += 1

            let optimalStart = try await findOptimalStartDate(
                targetEnd: currentEnd,
                earliestPossible: start,
                targetSteps: targetSteps
            )

            // Allow progress even if small - just check we moved backwards
            guard optimalStart < currentEnd else {
                // If truly stuck, jump back by 1 day to force progress
                let forcedStart = currentEnd.addingTimeInterval(-minIntervalDuration*4)
                if forcedStart >= start {
                    let interval = DateInterval(start: forcedStart, end: currentEnd)
                    let data = try await stepDataSource.getAggregatedStepData(for: interval)
                    intervals.append(SyncInterval(startDate: forcedStart, endDate: currentEnd, stepCount: data.count))
                    currentEnd = forcedStart
                } else {
                    break
                }
                continue
            }

            let interval = DateInterval(start: optimalStart, end: currentEnd)
            let data = try await stepDataSource.getAggregatedStepData(for: interval)

            intervals.append(
                SyncInterval(
                    startDate: optimalStart,
                    endDate: currentEnd,
                    stepCount: data.count
                )
            )

            currentEnd = optimalStart  // Move backwards
        }

        return intervals.reversed()
    }

    func findOptimalStartDate(
        targetEnd: Date,
        earliestPossible: Date,
        targetSteps: Int
    ) async throws -> Date {

        var low = earliestPossible
        var high = targetEnd
        var bestStart = targetEnd
        var bestDelta = Int.max
        var lastCount: Int?

        // Search until within 60 seconds (much more precise)
        while high.timeIntervalSince(low) > minIntervalDuration {
            let mid = Date(
                timeIntervalSince1970: (low.timeIntervalSince1970 + high.timeIntervalSince1970) / 2
            )

            let testInterval = DateInterval(start: mid, end: targetEnd)
            let data = try await stepDataSource.getAggregatedStepData(for: testInterval)

            let delta = abs(data.count - targetSteps)
            if delta < bestDelta {
                bestDelta = delta
                bestStart = mid
            }

            if lastCount == data.count {
                break
            }
            lastCount = data.count

            if data.count <= targetSteps {
                // Under limit - try going further BACK (earlier) to get more steps
                bestStart = mid
                high = mid
            } else {
                // Over limit - move FORWARD (later) to reduce steps
                low = mid
            }
        }

        return bestStart
    }
}
