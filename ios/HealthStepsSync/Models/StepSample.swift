import Foundation
import SwiftData

/// SwiftData model representing a single step count sample from HealthKit
@Model
final class StepSample {
    /// Unique identifier
    var id: UUID

    /// Start time of the sample
    var startDate: Date

    /// End time of the sample
    var endDate: Date

    /// Step count value
    var count: Int

    /// Source bundle identifier (e.g., com.apple.health, com.apple.Health)
    var sourceBundleId: String

    /// HealthKit sample UUID (for deduplication)
    var healthKitUUID: UUID

    /// Whether this sample has been synced to the API
    var isSynced: Bool

    /// Timestamp when synced to API
    var syncedAt: Date?

    /// Associated sync interval (for tracking which interval this sample belongs to)
    var syncIntervalId: UUID?

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        count: Int,
        sourceBundleId: String,
        healthKitUUID: UUID,
        isSynced: Bool = false,
        syncedAt: Date? = nil,
        syncIntervalId: UUID? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.count = count
        self.sourceBundleId = sourceBundleId
        self.healthKitUUID = healthKitUUID
        self.isSynced = isSynced
        self.syncedAt = syncedAt
        self.syncIntervalId = syncIntervalId
    }
}

/// Extension for JSON encoding (for API sync)
extension StepSample {
    var jsonRepresentation: [String: Any] {
        [
            "id": id.uuidString,
            "startDate": ISO8601DateFormatter().string(from: startDate),
            "endDate": ISO8601DateFormatter().string(from: endDate),
            "count": count,
            "sourceBundleId": sourceBundleId,
            "healthKitUUID": healthKitUUID.uuidString
        ]
    }
}
