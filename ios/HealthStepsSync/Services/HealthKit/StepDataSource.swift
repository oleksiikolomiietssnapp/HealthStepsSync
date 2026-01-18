//
//  StepDataSource.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.

import Foundation

/// Protocol for step data source
@MainActor
protocol StepDataSource {
    /// Check if the data source is available
    var isAvailable: Bool { get }

    var authStatus: HealthKitAuthStatus { get }

    /// Request authorization to read step count data
    func requestAuthorization() async throws

    func fetchStepBuckets(from startDate: Date, to endDate: Date, bucketMinutes: Int) async throws -> [StepBucket]

    /// Get raw step samples for a date interval (Stage 2a - Fetching)
    /// Returns array of individual step sample data
    func getRawStepSamples(for interval: DateInterval) async throws -> [StepSampleData]
}
