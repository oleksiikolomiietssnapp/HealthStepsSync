//
//  SwiftDataStorageProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation
import SwiftData

struct SyncIntervalData: Sendable {
    let startDate: Date
    let endDate: Date
    let stepCount: Int
}

@MainActor
class SwiftDataStorageProvider: LocalStorageProvider {
    private let modelContext: ModelContext
    private let idCacheManager = CacheManager<UUID>()
    private var leftoversFlushTask: Task<(), any Error>? = nil

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func insertInterval(
        startDate: Date,
        endDate: Date,
        stepCount: Int,
    ) async throws {
        let syncInterval = SyncInterval(
            startDate: startDate,
            endDate: endDate,
            stepCount: stepCount
        )
        modelContext.insert(syncInterval)
    }

    func deleteIntervals() throws {
        try modelContext.delete(model: SyncInterval.self)
    }

    func save() throws {
        try modelContext.save()
    }

    func updateSyncedToServer(_ id: UUID) async throws {
        await idCacheManager.append(id)

        if await idCacheManager.count >= 42 {
            try await flushSyncedIDs()
            leftoversFlushTask?.cancel()
            leftoversFlushTask = Task { [weak self] in
                try await Task.sleep(nanoseconds: 1_000_000_000)
                try Task.checkCancellation()
                try await self?.flushSyncedIDs()
            }
        }
    }

    func flushSyncedIDs() async throws {
        let toSync = await idCacheManager.drain()
        guard !toSync.isEmpty else { return }

        let backgroundContext = ModelContext(modelContext.container)
        let descriptor = FetchDescriptor<SyncInterval>(
            predicate: #Predicate { toSync.contains($0.id) }
        )

        let models = try backgroundContext.fetch(descriptor)
        for model in models {
            model.syncedToServer = true
        }

        try backgroundContext.save()
    }
}

actor CacheManager<T> {
    var cache: [T] = []

    func append(_ id: T) {
        cache.append(id)
    }

    func drain() -> [T] {
        let drained = cache
        cache.removeAll()
        return drained
    }

    var count: Int { cache.count }
}
