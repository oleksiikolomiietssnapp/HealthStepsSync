import Foundation

/// Low-level service that handles all HealthKit interactions
/// Provides async/await interface for authorization and queries
@MainActor
final class HealthKitStepDataSource<T: StepStatisticsQuerying>: StepDataSource {

    // MARK: - Properties
    private let stepQuery: T

    var isAvailable: Bool {
        stepQuery.isAvailable
    }

    var authStatus: HealthKitAuthStatus {
        stepQuery.authorizationStatus
    }

    // MARK: - Initialization

    init(stepQuery: T) {
        self.stepQuery = stepQuery
    }

    // MARK: - Authorization

    /// Request authorization to read step count data
    func requestAuthorization() async throws {
        try await stepQuery.requestAuthorization()
    }

    // MARK: - Aggregated Query (Stage 1 - Layering)
    
    func fetchStepBuckets(
        from startDate: Date,
        to endDate: Date,
        bucketMinutes: Int
    ) async throws -> [StepBucket] {
        try await stepQuery.fetchStepBuckets(from: startDate, to: endDate, bucketMinutes: bucketMinutes)
    }

    // MARK: - Raw Sample Query (Stage 2a - Fetching)

    /// Get raw step samples for a date interval
    /// Returns array of individual step sample data
    /// - Parameter interval: The time interval to query
    /// - Returns: Array of step samples as StepSampleData
    func getRawStepSamples(for interval: DateInterval) async throws -> [StepSampleData] {
        try await stepQuery.fetchStepSamples(for: interval)
    }

    // MARK: - Convenience Method

    /// Fetch step samples with direct date parameters (convenience wrapper)
    /// - Parameters:
    ///   - from: Start date
    ///   - to: End date
    /// - Returns: Array of step samples
    func fetchStepSamples(from: Date, to: Date) async throws -> [StepSampleData] {
        let interval = DateInterval(start: from, end: to)
        return try await getRawStepSamples(for: interval)
    }
}

#if DEBUG
    extension HealthKitStepDataSource where T == HealthKitStepStatisticsQuery {
        func feedSimulator() async throws {
            try await stepQuery.addRealisticStepDataForPastMonth()
        }

        // MARK: - Admin Data Manipulation (Testing/Development)

        /// Add realistic step data for the past month
        func addRealisticStepDataForPastMonth() async throws {
            try await stepQuery.addRealisticStepDataForPastMonth()
        }

        /// Add realistic step data for the past year
        func addRealisticStepDataForPastYear() async throws {
            try await stepQuery.addRealisticStepDataForPastYear()
        }

        /// Add realistic step data for the past 10 years
        func addRealisticStepDataForPast10Years() async throws {
            try await stepQuery.addRealisticStepDataForPast10Years()
        }

        /// Remove all step data from HealthKit
        func removeAllStepData() async throws {
            try await stepQuery.removeAllStepData()
        }
    }
#endif
