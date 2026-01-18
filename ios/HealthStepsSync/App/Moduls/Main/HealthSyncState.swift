//
//  HealthSyncState.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import Foundation

enum HealthSyncState: Equatable {
    case idle
    case layering
    case readyToSync
    case syncing(progress: SyncProgress)
    case paused(progress: SyncProgress)
    case completed
    case failed(SyncError)

    struct SyncProgress: Equatable {
        let synced: Int
        let total: Int
        let canResume: Bool
    }

    enum SyncError: Equatable {
        case layeringFailed(reason: String)
        case syncFailed(reason: String, canRetry: Bool)
        case dataIntegrityError

        var canRetry: Bool {
            switch self {
            case .layeringFailed: true
            case .syncFailed(_, let canRetry): canRetry
            case .dataIntegrityError: false
            }
        }
    }

    init(chunks: [SyncInterval]?) {
        guard let chunks, !chunks.isEmpty else {
            self = .idle
            return
        }

        let syncedCount = chunks.filter { $0.syncedToServer }.count
        let total = chunks.count

        switch syncedCount {
        case 0:
            self = .readyToSync
        case total:
            self = .completed
        default:
            self = .paused(
                progress: SyncProgress(
                    synced: syncedCount,
                    total: total,
                    canResume: true
                )
            )
        }
    }

    // State validation helpers
    var canStartSync: Bool {
        if case .readyToSync = self { return true }
        return false
    }

    var canResume: Bool {
        if case .paused = self { return true }
        return false
    }

    var canReset: Bool {
        switch self {
        case .idle, .layering, .syncing: return false
        default: return true
        }
    }

    var canUpdateFromPersistence: Bool {
        switch self {
        case .syncing, .layering: false
        default: true
        }
    }
}
