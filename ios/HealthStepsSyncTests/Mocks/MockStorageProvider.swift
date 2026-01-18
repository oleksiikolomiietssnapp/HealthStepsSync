//
//  MockStorageProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/16/26.
//

import OSLog
import Foundation

class MockStorageProvider: LocalStorageProvider {
    func insertInterval(startDate: Date, endDate: Date, stepCount: Int) async throws {
        os_log(.debug, "%i %@",
            stepCount,
            DateComponentsFormatter.duration.string(
                from: startDate, to: endDate
            ) ?? "-"
        )
    }

    func updateSyncedToServer(_ id: UUID) throws {
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
