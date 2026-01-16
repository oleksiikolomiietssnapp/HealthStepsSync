//
//  LocalStorageProvider.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation

protocol LocalStorageProvider {
    func insertInterval(_ interval: SyncInterval)
    func deleteIntervals() throws
    func save() throws
}
