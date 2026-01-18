//
//  MockStorageProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/16/26.
//

import OSLog
import Foundation

class MockStorageProvider: LocalStorageProvider {
    func updateSyncedToServer(_ id: UUID) throws {
        os_log(.debug, "Synced %@", id.uuidString)
    }

    func insertInterval(_ interval: HealthStepsSync.SyncInterval) {
        os_log(.debug, "%i %@",
            interval.stepCount,
            DateComponentsFormatter.duration.string(
                from: interval.startDate,
                to: interval.endDate
            ) ?? "-"
        )
    }

    func deleteIntervals() throws {

    }

    func save() throws {

    }
}

extension LocalStorageProvider where Self == MockStorageProvider {
    static func mock() -> MockStorageProvider {
        MockStorageProvider()
    }
}
