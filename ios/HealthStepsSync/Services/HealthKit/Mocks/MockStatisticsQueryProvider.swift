//
//  MockStatisticsQueryProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation

@MainActor
class MockStatisticsQueryProvider: StatisticsQueryProvider {
    var isAvailable: Bool {
        true
    }
    // MARK: - Configuration

    /// Average steps per day for mock data generation
    private let avgStepsPerDay: ClosedRange<Int> = 3000...30000

    /// Simulate network delay (in nanoseconds)
    private let simulatedDelay: UInt64 = 5_000

    /// Optional seed for reproducible results (nil = random)
    private let seed: Int?

    // MARK: - Initialization

    init(seed: Int? = nil) {
        self.seed = seed
    }

    // MARK: - StatisticsQueryProvider

    func requestAuthorization() async throws {

    }

    func authorizationStatus() -> HealthKitAuthStatus {
        .authorized
    }

    func getAggregatedStepCount(for interval: DateInterval) async throws -> AggregatedStepData {
        AggregatedStepData(count: generateMockStepCount(for: interval), startDate: interval.start, endDate: interval.end)
    }

    func getRawStepSamples(for interval: DateInterval) async throws -> [StepSampleData] {
        // Simulate network/query delay (slightly longer than aggregated)
        try await Task.sleep(nanoseconds: simulatedDelay)  // 100ms

        return generateMockStepSamples(for: interval)
    }

    // MARK: - Mock Sample Generation

    private func generateMockStepSamples(for interval: DateInterval) -> [StepSampleData] {
        var samples: [MockStepSample] = []
        var currentDate = interval.start

        while currentDate < interval.end {
            // 50-200 samples per day (walking sessions, background counting, etc.)
            let samplesPerDay = Int.random(in: 50...200)
            let secondsPerSample = 86400 / samplesPerDay

            for _ in 0..<samplesPerDay {
                let sampleDuration = TimeInterval.random(in: 30...300)  // 30s to 5min
                let endDate = currentDate.addingTimeInterval(sampleDuration)

                guard endDate <= interval.end else { break }

                let sample = MockStepSample(
                    uuid: UUID(),
                    startDate: currentDate,
                    endDate: endDate,
                    count: Int.random(in: 10...500),
                    sourceBundleId: "com.apple.health.mock",
                    sourceDeviceName: HealthDeviceModel.random.rawValue
                )
                samples.append(sample)

                currentDate = currentDate.addingTimeInterval(TimeInterval(secondsPerSample))
            }

            // Move to next day
            currentDate = Calendar.current.startOfDay(for: currentDate.addingTimeInterval(86400))
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
