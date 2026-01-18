//
//  WorstCaseMockStatisticsQueryProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/16/26.
//

import Foundation

class WorstCaseMockStatisticsQueryProvider: MockStatisticsQueryProvider {
    override func getAggregatedStepCount(for interval: DateInterval) async throws -> AggregatedStepData {
        AggregatedStepData(
            count: generateMockStepCount(for: interval),
            startDate: interval.start,
            endDate: interval.end
        )
    }

    private func generateMockStepCount(for interval: DateInterval) -> Int {
        let duration = interval.duration
        let numberOfDays = Int((duration / 86400).rounded(.down))
        var totalSteps = 0

        let year = Calendar.current.date(byAdding: .year, value: -2, to: .now)!
        for dayOffset in 0..<numberOfDays {
            let date = Calendar.current.date(
                byAdding: .day,
                value: dayOffset,
                to: interval.start
            )!

            if !Calendar.current.isDate(date, equalTo: year, toGranularity: .year),
               dayOffset%2 == 0  {
                totalSteps += worstCaseDailySteps(for: date)
            }
        }

        return totalSteps
    }

    private func worstCaseDailySteps(for date: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date)

        // Sunday = 1 in Gregorian calendar
        if weekday == 1 {
            return 10_000
        } else {
            return 1_200
        }
    }
}
