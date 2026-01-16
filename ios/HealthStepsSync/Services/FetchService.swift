import Foundation
import SwiftData
import HealthKit

/// Stage 2a: Fetch raw step data from HealthKit and store in SwiftData
/// Processes SyncInterval records in .pending status
//@MainActor
//final class FetchService {
//    private let healthKitManager: HealthKitManager<HealthKitStatisticsQueryProvider>
//    private let modelContext: ModelContext
//
//    init(healthKitManager: HealthKitManager<HealthKitStatisticsQueryProvider>, modelContext: ModelContext) {
//        self.healthKitManager = healthKitManager
//        self.modelContext = modelContext
//    }
//
//    /// Fetches step data for a specific sync interval
//    /// - Parameter interval: The SyncInterval to fetch data for
//    /// - Returns: Number of samples fetched
//    func fetchInterval(_ interval: SyncInterval) async throws -> Int {
//        // Update status to fetching
//        interval.status = .fetchingFromHealthKit
//        try modelContext.save()
//
//        do {
//            // Query HealthKit for step samples in this interval
//            let samples = try await healthKitManager.fetchStepSamples(
//                from: interval.startDate,
//                to: interval.endDate
//            )
//
//            // Store samples in SwiftData
//            var savedCount = 0
//            for sample in samples {
//                // Check for duplicates using HealthKit UUID
//                let exists = try await sampleExists(healthKitUUID: sample.uuid)
//                if !exists {
//                    let stepSample = StepSample(
//                        startDate: sample.startDate,
//                        endDate: sample.endDate,
//                        count: Int(sample.count),
//                        sourceBundleId: sample.sourceBundleId,
//                        healthKitUUID: sample.uuid,
//                        syncIntervalId: interval.id
//                    )
//                    modelContext.insert(stepSample)
//                    savedCount += 1
//                }
//            }
//
//            // Update interval status
//            interval.status = .readyToSync
//            interval.sampleCount = savedCount
//            interval.lastSyncDate = Date()
//            try modelContext.save()
//
//            return savedCount
//
//        } catch {
//            // Mark interval as failed
//            interval.status = .failed
//            interval.errorMessage = error.localizedDescription
//            try modelContext.save()
//            throw error
//        }
//    }
//
//    /// Checks if a sample with the given HealthKit UUID already exists
//    private func sampleExists(healthKitUUID: UUID) async throws -> Bool {
//        let predicate = #Predicate<StepSample> { sample in
//            sample.healthKitUUID == healthKitUUID
//        }
//
//        let descriptor = FetchDescriptor<StepSample>(predicate: predicate)
//        let samples = try modelContext.fetch(descriptor)
//
//        return !samples.isEmpty
//    }
//
//    /// Fetches all pending intervals
//    func fetchPendingIntervals() async throws -> Int {
//        let predicate = #Predicate<SyncInterval> { interval in
//            interval.status.rawValue == "pending"
//        }
//
//        let descriptor = FetchDescriptor<SyncInterval>(
//            predicate: predicate,
//            sortBy: [SortDescriptor(\.startDate, order: .forward)]
//        )
//
//        let pendingIntervals = try modelContext.fetch(descriptor)
//
//        var totalFetched = 0
//        for interval in pendingIntervals {
//            let count = try await fetchInterval(interval)
//            totalFetched += count
//        }
//
//        return totalFetched
//    }
//
//    /// Gets intervals ready to sync to API
//    func getReadyToSyncIntervals() async throws -> [SyncInterval] {
//        let predicate = #Predicate<SyncInterval> { interval in
//            interval.status.rawValue == "readyToSync"
//        }
//
//        let descriptor = FetchDescriptor<SyncInterval>(
//            predicate: predicate,
//            sortBy: [SortDescriptor(\.startDate, order: .forward)]
//        )
//
//        return try modelContext.fetch(descriptor)
//    }
//}



import Playgrounds

#Playground {
    struct IntervalInfo {
        var count: Int
        let start: Date
        let end: Date
    }
    let startDate = Calendar.current.date(from: .init(year: 2026, month: 1, day: 1))!
    let endDate = startDate.addingTimeInterval(100)
//    let count = 67

    let rawData = [
        IntervalInfo(count: 21, start: startDate, end: startDate.addingTimeInterval(10)),
        IntervalInfo(count: 3, start: startDate.addingTimeInterval(10), end: startDate.addingTimeInterval(20)),

        IntervalInfo(count: 0, start: startDate.addingTimeInterval(20), end: startDate.addingTimeInterval(25)),
        IntervalInfo(count: 0, start: startDate.addingTimeInterval(25), end: startDate.addingTimeInterval(26)),
        IntervalInfo(count: 0, start: startDate.addingTimeInterval(26), end: startDate.addingTimeInterval(30)),
        IntervalInfo(count: 0, start: startDate.addingTimeInterval(30), end: startDate.addingTimeInterval(40)),
        IntervalInfo(count: 0, start: startDate.addingTimeInterval(40), end: startDate.addingTimeInterval(50)),

        IntervalInfo(count: 0, start: startDate.addingTimeInterval(50), end: startDate.addingTimeInterval(60)),

        IntervalInfo(count: 0, start: startDate.addingTimeInterval(60), end: startDate.addingTimeInterval(70)),
        IntervalInfo(count: 3, start: startDate.addingTimeInterval(70), end: startDate.addingTimeInterval(80)),

        IntervalInfo(count: 21, start: startDate.addingTimeInterval(80), end: startDate.addingTimeInterval(90)),
        IntervalInfo(count: 70, start: startDate.addingTimeInterval(90), end: endDate)
    ]

    func optimizeIntervals(_ intervals: [IntervalInfo], maxCountPerInterval: Int = 20) -> [IntervalInfo] {
        guard !intervals.isEmpty else { return [] }

        var result: [IntervalInfo] = []
        var i = 0

        while i < intervals.count {
            let current = intervals[i]

            if current.count == 0 {
                // Merge consecutive zeros
                var end = current.end
                while i + 1 < intervals.count && intervals[i + 1].count == 0 {
                    i += 1
                    end = intervals[i].end
                }
                result.append(IntervalInfo(count: 0, start: current.start, end: end))
                i += 1

            } else if current.count > maxCountPerInterval {
                // Split large interval, don't merge with next
                result.append(contentsOf: splitInterval(current, maxCount: maxCountPerInterval))
                i += 1

            } else {
                // Try to merge small consecutive non-zero intervals
                var merged = current
                while i + 1 < intervals.count {
                    let next = intervals[i + 1]
                    if next.count == 0 || next.count > maxCountPerInterval {
                        break
                    }
                    if merged.count + next.count > maxCountPerInterval {
                        break
                    }
                    merged = IntervalInfo(count: merged.count + next.count, start: merged.start, end: next.end)
                    i += 1
                }
                result.append(merged)
                i += 1
            }
        }

        return result
    }

    func splitInterval(_ interval: IntervalInfo, maxCount: Int) -> [IntervalInfo] {
        let numberOfSplits = (interval.count + maxCount - 1) / maxCount
        let baseCount = interval.count / numberOfSplits
        let remainder = interval.count % numberOfSplits

        let totalDuration = interval.end.timeIntervalSince(interval.start)
        let durationPerSplit = totalDuration / Double(numberOfSplits)

        var result: [IntervalInfo] = []
        var currentStart = interval.start

        for i in 0..<numberOfSplits {
            let currentEnd = (i == numberOfSplits - 1)
                ? interval.end
                : currentStart.addingTimeInterval(durationPerSplit)

            // Distribute remainder to first chunks (larger chunks first)
            let splitCount = baseCount + (i < remainder ? 1 : 0)
            result.append(IntervalInfo(count: splitCount, start: currentStart, end: currentEnd))
            currentStart = currentEnd
        }

        return result
    }

    let optimized = optimizeIntervals(rawData, maxCountPerInterval: 60)
}

