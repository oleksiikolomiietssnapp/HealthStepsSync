//
//  StepStatisticsQuerying 2.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation

protocol StepStatisticsQuerying {
    var isAvailable: Bool { get }
    var authorizationStatus: HealthKitAuthStatus { get }

    func requestAuthorization() async throws
    func fetchStepBuckets(from startDate: Date, to endDate: Date, bucketMinutes: Int) async throws -> [StepBucket]
    func fetchStepSamples(for interval: DateInterval) async throws -> [StepSampleData]
}
