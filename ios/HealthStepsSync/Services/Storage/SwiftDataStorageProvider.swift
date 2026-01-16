//
//  SwiftDataStorageProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import SwiftData
import Foundation

class SwiftDataStorageProvider: LocalStorageProvider {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func insertInterval(_ interval: SyncInterval) {
        modelContext.insert(interval)
    }

    func deleteIntervals() throws {
        try modelContext.delete(model: SyncInterval.self)
    }

    func save() throws {
        try modelContext.save()
    }
}
