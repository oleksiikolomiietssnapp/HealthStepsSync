import Foundation
import SwiftData

/// Stage 2b: Sync SwiftData to API
/// Sends StepSample records to the backend API
@MainActor
final class APISyncService {
    private let modelContext: ModelContext
    private let apiBaseURL: URL

    /// Batch size for API requests (number of samples per request)
    private let batchSize: Int

    init(
        modelContext: ModelContext,
        apiBaseURL: URL,
        batchSize: Int = 100
    ) {
        self.modelContext = modelContext
        self.apiBaseURL = apiBaseURL
        self.batchSize = batchSize
    }

    /// Syncs all unsynced samples to the API
    /// - Returns: Number of samples successfully synced
    func syncUnsyncedSamples() async throws -> Int {
        let unsyncedSamples = try await getUnsyncedSamples()

        guard !unsyncedSamples.isEmpty else {
            return 0
        }

        var totalSynced = 0

        // Process in batches
        for batchStart in stride(from: 0, to: unsyncedSamples.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, unsyncedSamples.count)
            let batch = Array(unsyncedSamples[batchStart..<batchEnd])

            do {
                try await syncBatch(batch)
                totalSynced += batch.count
            } catch {
                print("Failed to sync batch starting at \(batchStart): \(error)")
                // Continue with next batch even if this one fails
            }
        }

        return totalSynced
    }

    /// Syncs a specific interval to the API
    /// - Parameter interval: The SyncInterval to sync
    func syncInterval(_ interval: SyncInterval) async throws {
        // Get all samples for this interval
//        let samples = try await getSamplesForInterval(interval.id)
//
//        guard !samples.isEmpty else {
//            // No samples to sync, mark as completed
//            interval.status = .completed
//            try modelContext.save()
//            return
//        }
//
//        // Update status
//        interval.status = .syncingToAPI
//        try modelContext.save()
//
//        do {
//            // Sync in batches
//            for batchStart in stride(from: 0, to: samples.count, by: batchSize) {
//                let batchEnd = min(batchStart + batchSize, samples.count)
//                let batch = Array(samples[batchStart..<batchEnd])
//                try await syncBatch(batch)
//            }
//
//            // Mark interval as completed
//            interval.status = .completed
//            interval.lastSyncDate = Date()
//            try modelContext.save()
//
//        } catch {
//            // Mark interval as failed
//            interval.status = .failed
//            interval.errorMessage = error.localizedDescription
//            try modelContext.save()
//            throw error
//        }
    }

    /// Syncs a batch of samples to the API
    private func syncBatch(_ samples: [StepSample]) async throws {
        let endpoint = apiBaseURL.appendingPathComponent("/steps")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert samples to JSON
        let jsonSamples = samples.map { $0.jsonRepresentation }
        let payload = ["samples": jsonSamples]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        // Mark samples as synced
        for sample in samples {
            sample.isSynced = true
            sample.syncedAt = Date()
        }

        try modelContext.save()
    }

    /// Gets all unsynced samples
    private func getUnsyncedSamples() async throws -> [StepSample] {
        let predicate = #Predicate<StepSample> { sample in
            sample.isSynced == false
        }

        let descriptor = FetchDescriptor<StepSample>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )

        return try modelContext.fetch(descriptor)
    }

    /// Gets samples for a specific interval
    private func getSamplesForInterval(_ intervalId: UUID) async throws -> [StepSample] {
        let predicate = #Predicate<StepSample> { sample in
            sample.syncIntervalId == intervalId && sample.isSynced == false
        }

        let descriptor = FetchDescriptor<StepSample>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )

        return try modelContext.fetch(descriptor)
    }

    /// Gets all intervals ready to sync
    func getReadyToSyncIntervals() async throws -> [SyncInterval] {
        []
//        let predicate = #Predicate<SyncInterval> { interval in
//            interval.status.rawValue == "readyToSync"
//        }
//
//        let descriptor = FetchDescriptor<SyncInterval>(
//            predicate: predicate,
//            sortBy: [SortDescriptor(\.startDate, order: .forward)]
//        )
//
//        return try modelContext.fetch(descriptor)
    }

    /// Syncs all ready intervals
    func syncAllReadyIntervals() async throws -> Int {
        let intervals = try await getReadyToSyncIntervals()

        var syncedCount = 0
        for interval in intervals {
            do {
                try await syncInterval(interval)
                syncedCount += 1
            } catch {
                print("Failed to sync interval \(interval.id): \(error)")
                // Continue with next interval
            }
        }

        return syncedCount
    }
}

/// API-related errors
enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}
