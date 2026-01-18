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

    func updateSyncedToServer(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SyncInterval>(
            predicate: #Predicate { $0.id == id }
        )

        if let model = try modelContext.fetch(descriptor).first {
            model.syncedToServer = true
            // Autosave handles persistence and avoid constant glitches
        }
    }
}
