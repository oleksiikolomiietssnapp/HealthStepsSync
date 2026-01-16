//
//  LayeringError.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation

enum LayeringError: Error, LocalizedError {
    case noDataAvailable
    case healthKitError(underlying: Error)
    case persistenceError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noDataAvailable:
            return "No step data available in HealthKit"
        case .healthKitError(let error):
            return "HealthKit error: \(error.localizedDescription)"
        case .persistenceError(let error):
            return "Failed to save intervals: \(error.localizedDescription)"
        }
    }
}
