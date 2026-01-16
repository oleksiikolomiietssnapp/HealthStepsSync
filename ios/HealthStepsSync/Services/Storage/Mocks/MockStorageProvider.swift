//
//  MockStorageProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/16/26.
//

import Foundation

class MockStorageProvider: LocalStorageProvider {
    func insertInterval(_ interval: HealthStepsSync.SyncInterval) {
        print(
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
