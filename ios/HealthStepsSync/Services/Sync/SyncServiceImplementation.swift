//
//  SyncServiceImplementation.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import Foundation

class SyncServiceImplementation: SyncService {
    private let health: StepDataProvider
    private let network: NetworkService
    private let storageProvider: LocalStorageProvider

    init(
        health: some StepDataProvider,
        network: some NetworkService,
        storageProvider: some LocalStorageProvider
    ) {
        self.health = health
        self.network = network
        self.storageProvider = storageProvider
    }

    func sync(id: UUID, startDate: Date, endDate: Date) async throws {
        let dateInterval = DateInterval(start: startDate, end: endDate)
        /// Fetches raw step samples from HealthKit for the given date range.
        let rawSteps = try await health.getRawStepSamples(for: dateInterval)

        // Convert all raw steps to API models
        let apiSamples = rawSteps.map { $0.toAPIModel() }

        /// Wraps API samples array into request body for POST /steps endpoint.
        let request = PostStepsRequest(samples: apiSamples)

        // Send all samples in one POST request
        let _: PostStepsResponse = try await network.post(.postSteps, body: request)

        // Set flag syncedToServer to true
        try await storageProvider.updateSyncedToServer(id)
    }
}
