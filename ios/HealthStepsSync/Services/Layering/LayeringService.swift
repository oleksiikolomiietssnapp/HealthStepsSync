//
//  LayeringService.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation

@MainActor
protocol LayeringService {
    /// Performs layering: discovers intervals with ≤10,000 steps each
    @discardableResult
    func performLayering() async throws -> [SyncInterval]

    /// Deletes all existing SyncInterval records (for restart)
    func clearAllIntervals() async throws
}
