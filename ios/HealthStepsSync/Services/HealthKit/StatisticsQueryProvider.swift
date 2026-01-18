//
//  StatisticsQueryProvider 2.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation

protocol StatisticsQueryProvider {
    var isAvailable: Bool { get }

    func requestAuthorization() async throws
    func authorizationStatus() -> HealthKitAuthStatus
    func getAggregatedStepCount(for interval: DateInterval) async throws -> AggregatedStepData
    func getRawStepSamples(for interval: DateInterval) async throws -> [StepSampleData]

    func addRealisticStepDataForPastMonth() async throws
    func removeAllStepData() async throws
    func addRealisticStepDataForPastYear() async throws
    func addRealisticStepDataForPast10Years() async throws
}
