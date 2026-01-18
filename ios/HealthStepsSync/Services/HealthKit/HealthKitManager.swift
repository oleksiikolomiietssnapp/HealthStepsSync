import Foundation

/// Low-level service that handles all HealthKit interactions
/// Provides async/await interface for authorization and queries
@MainActor
final class HealthKitManager<T: StatisticsQueryProvider>: StepDataProvider {

    // MARK: - Properties
    private let healthKitProvider: StatisticsQueryProvider

    var isAvailable: Bool {
        healthKitProvider.isAvailable
    }

    var authStatus: HealthKitAuthStatus {
        healthKitProvider.authorizationStatus()
    }

    // MARK: - Initialization

    init(healthKitProvider: T) {
        self.healthKitProvider = healthKitProvider
    }

    // MARK: - Authorization

    /// Request authorization to read step count data
    func requestAuthorization() async throws {
        try await healthKitProvider.requestAuthorization()
    }

    // MARK: - Aggregated Query (Stage 1 - Layering)

    /// Get aggregated step count for a date interval
    /// Returns total steps in the interval, used to decide if we need to subdivide
    /// - Parameter interval: The time interval to query
    /// - Returns: Total step count in the interval
    func getAggregatedStepData(for interval: DateInterval) async throws -> AggregatedStepData {
        if let result = try? await healthKitProvider.getAggregatedStepCount(for: interval) {
            return result
        } else {
            return AggregatedStepData(
                count: 0,
                startDate: interval.start,
                endDate: interval.end
            )
        }
    }

    // MARK: - Raw Sample Query (Stage 2a - Fetching)

    /// Get raw step samples for a date interval
    /// Returns array of individual step sample data
    /// - Parameter interval: The time interval to query
    /// - Returns: Array of step samples as StepSampleData
    func getRawStepSamples(for interval: DateInterval) async throws -> [StepSampleData] {
        try await healthKitProvider.getRawStepSamples(for: interval)
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

    func feedSimulator() async throws {
        try await healthKitProvider.addRealisticStepDataForPastMonth()
    }

    // MARK: - Admin Data Manipulation (Testing/Development)

    /// Add realistic step data for the past month
    func addRealisticStepDataForPastMonth() async throws {
        try await healthKitProvider.addRealisticStepDataForPastMonth()
    }

    /// Add realistic step data for the past year
    func addRealisticStepDataForPastYear() async throws {
        try await healthKitProvider.addRealisticStepDataForPastYear()
    }

    /// Add realistic step data for the past 10 years
    func addRealisticStepDataForPast10Years() async throws {
        try await healthKitProvider.addRealisticStepDataForPast10Years()
    }

    /// Remove all step data from HealthKit
    func removeAllStepData() async throws {
        try await healthKitProvider.removeAllStepData()
    }
}
