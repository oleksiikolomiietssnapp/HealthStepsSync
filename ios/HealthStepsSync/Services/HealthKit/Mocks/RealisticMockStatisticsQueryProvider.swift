//
//  RealisticMockStatisticsQueryProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/16/26.
//

import Foundation

class RealisticMockStatisticsQueryProvider: MockStatisticsQueryProvider {
    private let avgStepsPerDay: ClosedRange<Int> = 3000...30000

    override func getAggregatedStepCount(for interval: DateInterval) async throws -> AggregatedStepData {
        AggregatedStepData(count: generateMockStepCount(for: interval), startDate: interval.start, endDate: interval.end)
    }

    private func generateMockStepCount(for interval: DateInterval) -> Int {
        let duration = interval.duration
        let days = max(0, duration / 86400)

        if days < 1 {
            let hoursInInterval = duration / 3600
            let avgStepsPerHour = Double(avgStepsPerDay.lowerBound + avgStepsPerDay.upperBound) / (2 * 24)
            return Int(hoursInInterval * avgStepsPerHour)
        }

        let numberOfDays = Int(days.rounded(.down))
        var totalSteps = 0

        // Randomly decide if this entire interval contains a "dead week"
        let hasDeadWeek = Bool.random(probability: 0.15)  // 15% chance

        for dayOffset in 0..<numberOfDays {
            if hasDeadWeek && isInDeadWeek(dayOffset: dayOffset) {
                continue  // 0 steps
            }

            let daySteps = generateDailySteps(for: interval.start, dayOffset: dayOffset)
            totalSteps += daySteps
        }

        let remainingDuration = duration.truncatingRemainder(dividingBy: 86400)
        if remainingDuration > 0 {
            let lastDaySteps = generateDailySteps(for: interval.start, dayOffset: numberOfDays)
            let proportionalSteps = Int(Double(lastDaySteps) * (remainingDuration / 86400))
            totalSteps += proportionalSteps
        }

        return totalSteps
    }
    private func generateDailySteps(for startDate: Date, dayOffset: Int) -> Int {

        // 20% chance of no activity at all
        if Bool.random(probability: 0.20) {
            return 0
        }

        let behaviorRoll = Double.random(in: 0...1)
        let base = Int.random(in: avgStepsPerDay)

        switch behaviorRoll {
        case 0..<0.25:
            // Lazy day (very low steps)
            return Int(Double(base) * Double.random(in: 0.05...0.25))

        case 0.25..<0.80:
            // Normal day with variation
            return Int(Double(base) * Double.random(in: 0.7...1.2))

        default:
            // Active day
            return Int(Double(base) * Double.random(in: 1.3...1.8))
        }
    }

    private func isInDeadWeek(dayOffset: Int) -> Bool {
        // Any continuous 7-day block
        let weekIndex = dayOffset / 7
        return weekIndex == Int.random(in: 0...4)
    }
}
