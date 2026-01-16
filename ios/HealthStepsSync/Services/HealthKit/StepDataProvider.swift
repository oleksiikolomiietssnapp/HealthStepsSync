//
//  StepDataProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.

import Foundation

/// Protocol for step data providers (real HealthKit or mock)
@MainActor
protocol StepDataProvider {
    /// Check if the data source is available
    var isAvailable: Bool { get }

    /// Request authorization to read step count data
    func requestAuthorization() async throws

    /// Get aggregated step count for a date interval (Stage 1 - Layering)
    /// Returns total steps in the interval, used to decide if we need to subdivide
    func getAggregatedStepData(for interval: DateInterval) async throws -> AggregatedStepData

    /// Get raw step samples for a date interval (Stage 2a - Fetching)
    /// Returns array of individual step sample data
    func getRawStepSamples(for interval: DateInterval) async throws -> [StepSampleData]
}
