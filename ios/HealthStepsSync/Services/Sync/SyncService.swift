//
//  SyncService.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/16/26.
//

import Foundation

protocol SyncService {
    func sync(id: UUID, startDate: Date, endDate: Date) async throws
}
