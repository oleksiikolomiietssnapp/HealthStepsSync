//
//  MockStorageProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/16/26.
//

import OSLog
import Foundation

class MockStorageProvider: LocalStorageProvider {
    var source: [UUID: SyncInterval] = [:]
    func insertInterval(startDate: Date, endDate: Date, stepCount: Int) async throws {
        let interval = SyncInterval(
            startDate: startDate,
            endDate: endDate,
            stepCount: stepCount
        )
        source[interval.id] = interval
        os_log(.debug, "%i %@",
            stepCount,
            DateComponentsFormatter.duration.string(
                from: startDate, to: endDate
            ) ?? "-"
        )
    }

    func updateSyncedToServer(_ id: UUID) throws {
        source[id]?.syncedToServer = true
        os_log(.debug, "Synced %@", id.uuidString)
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
