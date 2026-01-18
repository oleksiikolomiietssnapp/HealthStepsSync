//
//  SyncServiceImplementation.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import Foundation

class SyncServiceImplementation: SyncService {
    private let stepDataSource: StepDataSource
    private let network: NetworkService
    private let storageProvider: LocalStorageProvider

    init(
        stepDataSource: some StepDataSource,
        network: some NetworkService,
        storageProvider: some LocalStorageProvider
    ) {
        self.stepDataSource = stepDataSource
        self.network = network
        self.storageProvider = storageProvider
    }

    func sync(id: UUID, startDate: Date, endDate: Date) async throws {
        let dateInterval: DateInterval = DateInterval(start: startDate, end: endDate)
        /// Fetches raw step samples from HealthKit for the given date range.
        let rawSteps: [StepSampleData] = try await stepDataSource.getRawStepSamples(for: dateInterval)

        // Convert all raw steps to API models
        let apiSamples: [APIStepSample] = rawSteps.map { $0.toAPIModel() }

        /// Wraps API samples array into request body for POST /steps endpoint.
        let request: PostStepsRequest = PostStepsRequest(samples: apiSamples)

        // Send all samples in one POST request
        try await network.post(.postSteps, body: request)

        // Set flag syncedToServer to true
        try await storageProvider.updateSyncedToServer(id)
    }
}
