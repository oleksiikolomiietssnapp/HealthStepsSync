//
//  MockStatisticsQueryProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation

extension HealthKitStepDataSource where T == MockStatisticsQueryProvider {
    static func mock() -> Self {
        self.init(stepQuery: MockStatisticsQueryProvider())
    }
}

@MainActor
class MockStatisticsQueryProvider: StepStatisticsQuerying {
    let isAvailable: Bool = true
    let authorizationStatus: HealthKitAuthStatus = .authorized
    // MARK: - Configuration

    /// Average steps per day for mock data generation
    private let avgStepsPerDay: ClosedRange<Int> = 3000...30000

    /// Optional seed for reproducible results (nil = random)
    private let seed: Int?

    // MARK: - Initialization

    init(seed: Int? = nil) {
        self.seed = seed
    }

    // MARK: - StepStatisticsQuerying

    func requestAuthorization() async throws {

    }

    func fetchAggregatedStepCount(for interval: DateInterval) async throws -> AggregatedStepData {
        AggregatedStepData(count: generateMockStepCount(for: interval), startDate: interval.start, endDate: interval.end)
    }

    func fetchStepBuckets(from startDate: Date, to endDate: Date, bucketMinutes: Int) async throws -> [StepBucket] {
        []
    }

    func fetchStepSamples(for interval: DateInterval) async throws -> [StepSampleData] {
        generateMockStepSamples(for: interval)
    }

    // MARK: - Mock Sample Generation

    private func generateMockStepSamples(for interval: DateInterval) -> [StepSampleData] {
        var samples: [MockStepSample] = []
        samples.reserveCapacity(1000)  // Pre-allocate reasonable size

        var currentDate = interval.start
        let calendar = Calendar.current

        while currentDate < interval.end {
            let samplesPerDay = Int.random(in: 50...200)
            let dayEnd = min(
                calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: currentDate))!,
                interval.end
            )

            let secondsAvailable = dayEnd.timeIntervalSince(currentDate)
            let secondsPerSample = secondsAvailable / Double(samplesPerDay)

            for _ in 0..<samplesPerDay {
                let duration = TimeInterval.random(in: 30...300)
                let endDate = min(currentDate.addingTimeInterval(duration), dayEnd)

                guard endDate <= interval.end else { break }

                samples.append(
                    MockStepSample(
                        uuid: UUID(),
                        startDate: currentDate,
                        endDate: endDate,
                        count: Int.random(in: 10...500),
                        sourceBundleId: "com.apple.health.mock",
                        sourceDeviceName: "iPhone SE"
                    )
                )

                currentDate = currentDate.addingTimeInterval(secondsPerSample)
                if currentDate >= dayEnd { break }
            }

            currentDate = calendar.startOfDay(for: currentDate.addingTimeInterval(86400))
        }

        return samples
    }

    // MARK: - Mock Data Generation

    private func generateMockStepCount(for interval: DateInterval) -> Int {
        // Calculate number of full days in the interval
        let duration = interval.duration
        let days = max(0, duration / 86400)  // 86400 seconds per day

        // Handle partial days and intervals less than a day
        if days < 1 {
            // For intervals less than a day, calculate proportional steps
            let hoursInInterval = duration / 3600
            let avgStepsPerHour = Double(avgStepsPerDay.lowerBound + avgStepsPerDay.upperBound) / (2 * 24)
            return Int(hoursInInterval * avgStepsPerHour)
        }

        // For multi-day intervals, generate realistic daily variation
        var totalSteps = 0
        let numberOfDays = Int(days.rounded(.down))

        for dayOffset in 0..<numberOfDays {
            let daySteps = generateDailySteps(for: interval.start, dayOffset: dayOffset)
            totalSteps += daySteps
        }

        // Handle remaining partial day
        let remainingDuration = duration.truncatingRemainder(dividingBy: 86400)
        if remainingDuration > 0 {
            let lastDaySteps = generateDailySteps(for: interval.start, dayOffset: numberOfDays)
            let proportionalSteps = Int(Double(lastDaySteps) * (remainingDuration / 86400))
            totalSteps += proportionalSteps
        }

        return totalSteps
    }

    private func generateDailySteps(for startDate: Date, dayOffset: Int) -> Int {
        // Use seeded random if seed is provided, otherwise truly random
        if let seed = seed {
            // Create deterministic steps based on seed and day offset
            let combinedSeed = seed + dayOffset
            let normalized = Double(abs(combinedSeed) % 10001) / 10000.0  // 0.0 to 1.0
            let range = avgStepsPerDay.upperBound - avgStepsPerDay.lowerBound
            return avgStepsPerDay.lowerBound + Int(normalized * Double(range))
        } else {
            // Truly random
            return Int.random(in: avgStepsPerDay)
        }
    }
}

// MARK: - Mock Step Sample

/// Mock implementation of StepSampleData for testing
struct MockStepSample: StepSampleData {
    let uuid: UUID
    let startDate: Date
    let endDate: Date
    let count: Int
    let sourceBundleId: String
    let sourceDeviceName: String?
}
