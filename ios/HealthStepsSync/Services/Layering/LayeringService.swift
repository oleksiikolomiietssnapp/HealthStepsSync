//
//  LayeringService.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation
import OSLog

@MainActor
final class LayeringService: LayeringServiceProtocol {

    // MARK: - Constants

    private(set) var maxStepsPerInterval = 10_000
    private let maxYearsBack = 10
    private let minIntervalDuration: TimeInterval = 3600 * 24

    // MARK: - Dependencies

    private let stepDataProvider: StepDataProvider
    private let storageProvider: LocalStorageProvider

    // MARK: - Init

    init(
        stepDataProvider: StepDataProvider,
        storageProvider: LocalStorageProvider
    ) {
        self.stepDataProvider = stepDataProvider
        self.storageProvider = storageProvider
    }

    // MARK: - Public Methods

    func performLayering() async throws -> [SyncInterval] {
        // 1. Clear existing intervals (start fresh)
        try await clearAllIntervals()

        // 2. Define max range: 10 years ago to now
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .year, value: -maxYearsBack, to: endDate)!

        // 3. Check if any data exists in full range
        let fullInterval: DateInterval = DateInterval(start: startDate, end: endDate)
        let totalStepsData: AggregatedStepData = try await stepDataProvider.getAggregatedStepData(for: fullInterval)

        if totalStepsData.count == 0 {
            // No data at all - create single empty interval
            let interval = SyncInterval(
                startDate: startDate,
                endDate: endDate,
                stepCount: 0
            )
            storageProvider.insertInterval(interval)
            try storageProvider.save()
            return [interval]
        }

        // 4. Find actual data boundaries (optimization)
        let actualStart: Date = try await findDataStart(in: fullInterval)
        let actualEnd: Date = try await findDataEnd(in: fullInterval)

        // 5. Perform recursive layering
        let intervals: [SyncInterval] = try await chunks(
            forIntervalFrom: actualStart,
            to: actualEnd,
            limit: maxStepsPerInterval,
            api: stepDataProvider
        )
        os_log(.debug, "Layering id done")

        // 6. Save all intervals to LocalStorage
        for interval in intervals {
            storageProvider.insertInterval(interval)
        }
        try storageProvider.save()
        os_log(.debug, "Saving id done")

        return intervals
    }

    func clearAllIntervals() async throws {
        try storageProvider.deleteIntervals()
        try storageProvider.save()
    }

    // MARK: - Private Methods

    /// Binary search to find earliest date with data
    private func findDataStart(in interval: DateInterval) async throws -> Date {
        var low = interval.start
        var high = interval.end

        // Binary search to find earliest date with data
        while high.timeIntervalSince(low) > 86400 {  // Stop when within 1 day
            let mid = Date(
                timeIntervalSince1970: (low.timeIntervalSince1970 + high.timeIntervalSince1970) / 2
            )

            let firstHalf = DateInterval(start: low, end: mid)
            let stepsInFirstHalf = try await stepDataProvider.getAggregatedStepData(for: firstHalf)

            if stepsInFirstHalf.count > 0 {
                // Data exists in first half, search there
                high = mid
            } else {
                // No data in first half, search second half
                low = mid
            }
        }

        return low
    }

    /// Binary search to find latest date with data
    private func findDataEnd(in interval: DateInterval) async throws -> Date {
        var low = interval.start
        var high = interval.end

        // Binary search to find latest date with data
        while high.timeIntervalSince(low) > 86400 {  // Stop when within 1 day
            let mid = Date(
                timeIntervalSince1970: (low.timeIntervalSince1970 + high.timeIntervalSince1970) / 2
            )

            let secondHalf = DateInterval(start: mid, end: high)
            let stepsInSecondHalf = try await stepDataProvider.getAggregatedStepData(for: secondHalf)

            if stepsInSecondHalf.count > 0 {
                // Data exists in second half, search there
                low = mid
            } else {
                // No data in second half, search first half
                high = mid
            }
        }

        return high
    }

    func chunks(
        forIntervalFrom start: Date,
        to end: Date,
        limit: Int,
        api: StepDataProvider
    ) async throws -> [SyncInterval] {
        // Validate input
        guard start < end else {
            return []
        }

        // Fetch data for the entire interval
        let interval = DateInterval(start: start, end: end)
        let data = try await api.getAggregatedStepData(for: interval)

        // Base case: count is within limit
        if data.count <= limit {
            return [
                SyncInterval(
                    startDate: data.startDate,
                    endDate: data.endDate,
                    stepCount: data.count
                )
            ]
        }

        // Recursive case: need to subdivide
        let subdivisions = calculateSubdivisions(count: data.count, limit: limit)
        let subIntervals = divideInterval(start: start, end: end, into: subdivisions)

        var syncIntervals: [SyncInterval] = [SyncInterval]()
        // Recursively process each sub-interval and flatten results
        for subInterval in subIntervals {
            syncIntervals.append(
                contentsOf: try await chunks(
                    forIntervalFrom: subInterval.start,
                    to: subInterval.end,
                    limit: limit,
                    api: api
                )
            )
        }
        return syncIntervals
    }

    /// Calculates optimal number of subdivisions based on count/limit ratio
    /// Returns a value between 2 and 10 to prevent excessive fragmentation
    private func calculateSubdivisions(count: Int, limit: Int) -> Int {
        guard limit > 0 else { return 2 }

        // Calculate theoretical minimum subdivisions needed
        let theoreticalDivisions = Int(ceil(Double(count) / Double(limit)))

        // Cap at 10 to prevent excessive recursion
        let maxSubdivisions = 10

        // Ensure at least 2 subdivisions (binary split minimum)
        let minSubdivisions = 2

        return min(max(theoreticalDivisions, minSubdivisions), maxSubdivisions)
    }

    /// Divides a date interval into N equal sub-intervals
    private func divideInterval(
        start: Date,
        end: Date,
        into subdivisions: Int
    ) -> [(start: Date, end: Date)] {
        guard subdivisions > 0 else { return [] }
        guard start < end else { return [] }

        let totalDuration = end.timeIntervalSince(start)
        let segmentDuration = totalDuration / Double(subdivisions)

        return (0..<subdivisions).map { index in
            let segmentStart = start.addingTimeInterval(Double(index) * segmentDuration)

            // For the last segment, use exact end date to avoid floating-point errors
            let segmentEnd =
                (index == subdivisions - 1)
                ? end
                : start.addingTimeInterval(Double(index + 1) * segmentDuration)

            return (start: segmentStart, end: segmentEnd)
        }
    }

}
