//
//  HealthKitStatisticsQueryProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation
import HealthKit

enum HealthKitQueryError: Error {
    case statisticIsNil
}

final class HealthKitStepStatisticsQuery: StepStatisticsQuerying {
    let healthStore: HKHealthStore
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var stepType: HKQuantityType {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            fatalError("StepCount HKQuantityType is missing")
        }
        return stepType
    }

    var authorizationStatus: HealthKitAuthStatus {
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

    init() {
        self.healthStore = HKHealthStore()
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }

        let toShare: Set<HKQuantityType>
        #if DEBUG
            toShare = [stepType]
        #else
            toShare = []
        #endif

        await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(
                toShare: toShare,
                read: [stepType]
            ) { success, error in
                print("success:", success, "error:", error as Any)
                continuation.resume()
            }
        }
    }

    func fetchAggregatedStepCount(for interval: DateInterval) async throws -> AggregatedStepData {
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
                    continuation.resume(throwing: error)
                    return
                }

                guard let statistics, let sum = statistics.sumQuantity() else {
                    continuation.resume(
                        throwing: HealthKitError.queryFailed(
                            underlying: HealthKitQueryError.statisticIsNil
                        )
                    )
                    return
                }
                let steps = Int(sum.doubleValue(for: .count()))

                let data = AggregatedStepData(
                    count: steps,
                    startDate: statistics.startDate,
                    endDate: statistics.endDate
                )

                continuation.resume(returning: data)
            }

            healthStore.execute(query)
        }
    }

    func fetchStepBuckets(
        from startDate: Date,
        to endDate: Date,
        bucketMinutes: Int
    ) async throws -> [StepBucket] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let anchor = Calendar.current.startOfDay(for: startDate)
        let interval = DateComponents(minute: bucketMinutes)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let collection else {
                    continuation.resume(returning: [])
                    return
                }

                var buckets: [StepBucket] = []
                collection.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    let steps = stats.sumQuantity()?.doubleValue(for: .count()).rounded() ?? 0
                    buckets.append(StepBucket(start: stats.startDate, end: stats.endDate, steps: Int(steps)))
                }

                continuation.resume(returning: buckets)
            }

            healthStore.execute(query)
        }
    }

    func fetchStepSamples(for interval: DateInterval) async throws -> [StepSampleData] {
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )
        return try await withCheckedThrowingContinuation {  [weak self] continuation in
            guard let self else {
                continuation.resume(returning: [])
                return
            }
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: self.stepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results as? [StepSampleData] ?? [])
                }
            }
            healthStore.execute(query)
        }
    }
}

#if DEBUG
    // MARK: - Write Sample Data (For Testing/Development)
    extension StepStatisticsQuerying where Self == HealthKitStepStatisticsQuery {
        func removeAllStepData() async throws {
            let stepType = HKQuantityType(.stepCount)
            let predicate = HKQuery.predicateForSamples(withStart: .distantPast, end: Date())

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.healthStore.deleteObjects(of: stepType, predicate: predicate) { success, count, error in
                    if let error {
                        continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }

        /// Add realistic step data to HealthKit for the past 12 months
        /// Generates varied samples throughout each day mimicking real device behavior
        func addRealisticStepDataForPastYear() async throws {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? endDate
            let stepType = HKQuantityType(.stepCount)

            // Process in monthly batches to avoid memory/timeout issues
            for monthOffset in 0..<12 {
                guard let monthStart = Calendar.current.date(byAdding: .month, value: monthOffset, to: startDate) else {
                    continue
                }

                let daysInMonth = Calendar.current.range(of: .day, in: .month, for: monthStart)?.count ?? 30
                var samplesToSave: [HKSample] = []

                for dayOffset in 0..<daysInMonth {
                    guard let dayStart = Calendar.current.date(byAdding: .day, value: dayOffset, to: monthStart) else {
                        continue
                    }

                    let dailySamples = generateRealisticDaySamples(for: dayStart, stepType: stepType)
                    samplesToSave.append(contentsOf: dailySamples)
                }

                // Save each month separately (skip if empty)
                if !samplesToSave.isEmpty {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        self.healthStore.save(samplesToSave) { success, error in
                            if let error {
                                continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                }

                // Small delay between months to avoid rate limiting
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        /// Add realistic step data to HealthKit for the previous 10 years
        /// Generates varied samples throughout each day mimicking real device behavior
        func addRealisticStepDataForPast10Years() async throws {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .year, value: -10, to: endDate) ?? endDate
            let stepType = HKQuantityType(.stepCount)

            var currentDate = startDate

            while currentDate < endDate {
                // Realistic tracking gaps
                let hasDevice = shouldHaveDeviceData(for: currentDate)

                if hasDevice {
                    // Record 1-6 months of continuous data
                    let recordingDuration = Int.random(in: 30...180)  // days

                    // Process in weekly batches to manage memory
                    for weekOffset in 0..<(recordingDuration / 7) {
                        var samplesToSave: [HKSample] = []

                        for dayOffset in 0..<7 {
                            let totalOffset = (weekOffset * 7) + dayOffset
                            guard let dayStart = Calendar.current.date(byAdding: .day, value: totalOffset, to: currentDate),
                                dayStart < endDate
                            else { break }

                            let dailySamples = generateRealisticDaySamples(for: dayStart, stepType: stepType)
                            samplesToSave.append(contentsOf: dailySamples)
                        }

                        // Save weekly batch (skip if empty)
                        if !samplesToSave.isEmpty {
                            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                                self.healthStore.save(samplesToSave) { success, error in
                                    if let error {
                                        continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                                    } else {
                                        continuation.resume()
                                    }
                                }
                            }

                            try await Task.sleep(nanoseconds: 10_000_000)
                        }
                    }

                    currentDate = Calendar.current.date(byAdding: .day, value: recordingDuration, to: currentDate) ?? endDate
                } else {
                    // Gap: no device/tracking (2 weeks to 6 months)
                    let gapDuration = Int.random(in: 14...180)
                    currentDate = Calendar.current.date(byAdding: .day, value: gapDuration, to: currentDate) ?? endDate
                }
            }
        }

        private func shouldHaveDeviceData(for date: Date) -> Bool {
            // 80% chance of having tracking device
            // More likely in recent years
            let yearsSinceDate = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
            let baseProbability = 0.8
            let agePenalty = Double(yearsSinceDate) * 0.05

            return Double.random(in: 0...1) < (baseProbability - agePenalty)
        }

        /// Add realistic step data to HealthKit for the past month
        /// Generates varied samples throughout each day mimicking real device behavior
        func addRealisticStepDataForPastMonth() async throws {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .month, value: -1, to: endDate) ?? endDate

            var samplesToSave: [HKSample] = []
            let stepType = HKQuantityType(.stepCount)

            // Generate data for each day
            for dayOffset in 0..<30 {
                guard let dayStart = Calendar.current.date(byAdding: .day, value: dayOffset, to: startDate) else {
                    continue
                }

                let dailySamples = generateRealisticDaySamples(for: dayStart, stepType: stepType)
                samplesToSave.append(contentsOf: dailySamples)
            }

            guard !samplesToSave.isEmpty else {
                return
            }

            return try await withCheckedThrowingContinuation { continuation in
                self.healthStore.save(samplesToSave) { success, error in
                    if let error {
                        continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }

        private func generateRealisticDaySamples(for dayStart: Date, stepType: HKQuantityType) -> [HKSample] {
            var samples: [HKSample] = []
            let calendar = Calendar.current

            // Determine activity level for the day
            let dailyTotal = generateRealisticDailyTotal()

            // Generate 10-30 samples throughout the day (mimics real device behavior)
            let sampleCount = Int.random(in: 10...30)
            var remainingSteps = dailyTotal

            for i in 0..<sampleCount {
                // Spread samples throughout waking hours (6 AM - 11 PM)
                let hourOffset = Double.random(in: 6...23)
                let minuteOffset = Double.random(in: 0...59)
                let secondOffset = Double.random(in: 0...59)

                guard
                    let sampleTime = calendar.date(
                        bySettingHour: Int(hourOffset),
                        minute: Int(minuteOffset),
                        second: Int(secondOffset),
                        of: dayStart
                    )
                else { continue }

                // Last sample gets remaining steps, others get random portions
                let stepCount: Int
                if i == sampleCount - 1 {
                    stepCount = max(0, remainingSteps)
                } else {
                    let maxForThisSample = min(remainingSteps, 150)
                    if maxForThisSample < 5 {
                        stepCount = maxForThisSample
                    } else {
                        stepCount = Int.random(in: 5...maxForThisSample)
                    }
                    remainingSteps -= stepCount
                }

                // Sample duration: 1-5 minutes
                let duration = TimeInterval(Int.random(in: 60...300))
                let endTime = sampleTime.addingTimeInterval(duration)

                let sample = HKQuantitySample(
                    type: stepType,
                    quantity: HKQuantity(unit: .count(), doubleValue: Double(stepCount)),
                    start: sampleTime,
                    end: endTime,
                    device: HKDevice.local(),
                    metadata: [:]
                )

                samples.append(sample)
            }

            return samples
        }

        private func generateRealisticDailyTotal() -> Int {
            // 5% chance of very low activity (sick/rest day)
            if Bool.random(probability: 0.05) {
                return Int.random(in: 200...1500)
            }

            let behaviorRoll = Double.random(in: 0...1)

            switch behaviorRoll {
            case 0..<0.15:
                // Sedentary day
                return Int.random(in: 2000...5000)

            case 0.15..<0.70:
                // Normal day
                return Int.random(in: 5000...10000)

            case 0.70..<0.90:
                // Active day
                return Int.random(in: 10000...15000)

            default:
                // Very active day
                return Int.random(in: 15000...25000)
            }
        }
    }
#endif
