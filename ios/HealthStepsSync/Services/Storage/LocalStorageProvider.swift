//
//  LocalStorageProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation

@MainActor
protocol LocalStorageProvider {
    func insertInterval(startDate: Date, endDate: Date, stepCount: Int) async throws
    func updateSyncedToServer(_ id: UUID) async throws
    func deleteIntervals() throws
    func save() throws
}
