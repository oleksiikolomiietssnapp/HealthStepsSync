import Foundation
import SwiftData

/// Represents a date interval containing step data, discovered by LayeringServiceImplementation
/// Used for Stage 1 (Layering) - discovering intervals with ≤10,000 steps each
@Model
final class SyncInterval {
    @Attribute(.unique)
    var id: UUID
    var startDate: Date
    var endDate: Date
    var stepCount: Int
    var syncedToServer: Bool

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        stepCount: Int,
        syncedToServer: Bool = false
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.stepCount = stepCount
        self.syncedToServer = syncedToServer
    }
}
