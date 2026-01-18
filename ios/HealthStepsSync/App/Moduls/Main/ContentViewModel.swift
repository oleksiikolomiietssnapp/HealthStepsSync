//
//  ContentViewModel.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import Foundation
import SwiftData
import OSLog

@Observable
final class ContentViewModel {
    var state: HealthSyncState
    private var currentTask: Task<Void, Never>?

    private let stepDataSource: StepDataSource
    private let maxConcurrentSyncs: Int
    private let layeringService: LayeringService
    private let apiSyncService: SyncService
    private let network: NetworkService
    private let modelContext: ModelContext

    var healthAuthState: HealthKitAuthStatus {
        stepDataSource.authStatus
    }

    init(
        chunks: [SyncInterval]?,
        stepDataSource: some StepDataSource,
        layeringService: some LayeringService,
        apiSyncService: some SyncService,
        network: some NetworkService,
        modelContext: ModelContext,
        maxConcurrentSyncs: Int = 3
    ) {
        self.stepDataSource = stepDataSource
        self.maxConcurrentSyncs = maxConcurrentSyncs
        self.layeringService = layeringService
        self.apiSyncService = apiSyncService
        self.network = network
        self.modelContext = modelContext
        self.state = HealthSyncState(chunks: chunks)
    }

    func requestHealthAuthorization() {
        Task {
            do {
                try await stepDataSource.requestAuthorization()
            } catch {
                os_log(.error, "HealthKit authorization error: %@", error.localizedDescription)
            }
        }
    }

    func performAction(unsynchronizedChunks: [SyncInterval], totalChunks: Int) {
        switch state {
        case .idle:
            startLayering()
        case .readyToSync:
            startSyncing(chunks: unsynchronizedChunks, total: totalChunks)
        case .syncing:
            pauseSyncing()
        case .paused:
            resumeSyncing(chunks: unsynchronizedChunks, synced: totalChunks - unsynchronizedChunks.count, total: totalChunks)
        case .completed, .failed:
            reset()
        case .layering:
            break
        }
    }

    func updateProgress(synced: Int, total: Int) {
        guard case .syncing = state else { return }
        state = .syncing(progress: .init(synced: synced, total: total, canResume: true))
    }

    private func startLayering() {
        guard currentTask == nil else { return }
        state = .layering

        currentTask = Task { [weak self] in
            defer { self?.currentTask = nil }
            guard let self else { return }

            do {
                try await layeringService.performLayering()
                self.state = .readyToSync
            } catch {
                self.state = .failed(.layeringFailed(reason: error.localizedDescription))
            }
        }
    }

    private func startSyncing(chunks: [SyncInterval], total: Int) {
        guard currentTask == nil else { return }
        state = .syncing(progress: .init(synced: 0, total: total, canResume: true))

        currentTask = Task { [weak self] in
            defer { self?.currentTask = nil }
            guard let self else { return }

            do {
                try await self.syncChunks(chunks, totalCount: total)
                self.state = .completed
            } catch is CancellationError {
                // Paused by user
            } catch {
                self.state = .failed(
                    .syncFailed(
                        reason: error.localizedDescription,
                        canRetry: true
                    )
                )
            }
        }
    }

    private func syncChunksInBackground(_ chunks: [SyncInterval], totalCount: Int) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for chunk in chunks {
                try Task.checkCancellation()

                group.addTask {
                    try await self.apiSyncService.sync(
                        id: chunk.id,
                        startDate: chunk.startDate,
                        endDate: chunk.endDate
                    )
                }
                try await group.next()
            }
        }
    }

    private func resumeSyncing(chunks: [SyncInterval], synced: Int, total: Int) {
        guard currentTask == nil else { return }
        state = .syncing(progress: .init(synced: synced, total: total, canResume: true))

        currentTask = Task { [weak self] in
            defer { self?.currentTask = nil }
            guard let self else { return }

            do {
                try Task.checkCancellation()
                try await self.syncChunks(chunks, totalCount: total)
                self.state = .completed
            } catch is CancellationError {
                // Paused again
            } catch {
                self.state = .failed(
                    .syncFailed(
                        reason: error.localizedDescription,
                        canRetry: true
                    )
                )
            }
        }
    }

    private func syncChunks(_ chunks: [SyncInterval], totalCount: Int) async throws {
        try await withThrowingTaskGroup(of: Void.self) { [weak self] group in
            guard let self else { return }
            try Task.checkCancellation()
            var iterator = chunks.makeIterator()

            // Start initial batch concurrently
            for _ in 0..<self.maxConcurrentSyncs {
                guard let chunk = iterator.next() else { break }
                group.addTask { [weak self] in
                    guard let self else { return }
                    try await self.apiSyncService.sync(
                        id: chunk.id,
                        startDate: chunk.startDate,
                        endDate: chunk.endDate
                    )
                }
            }

            // As each completes, start next
            while try await group.next() != nil {
                try Task.checkCancellation()

                if let chunk = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        try await self.apiSyncService.sync(
                            id: chunk.id,
                            startDate: chunk.startDate,
                            endDate: chunk.endDate
                        )
                    }
                }
            }
        }
    }

    private func pauseSyncing() {
        guard case .syncing(let progress) = state else { return }
        currentTask?.cancel()
        currentTask = nil
        state = .paused(progress: progress)
    }

    private func reset() {
        currentTask?.cancel()
        currentTask = nil
        state = .idle
        Task {
            do {
                try modelContext.delete(model: SyncInterval.self)
                os_log("Erased local db.")
                let response = try await network.delete(.deleteSteps)
                os_log("Erased server db: %@.", response.message)
            } catch {
                os_log("%@", error.localizedDescription)
            }
        }
    }
}
