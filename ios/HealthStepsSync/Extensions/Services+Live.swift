//
//  HealthKitStepDataSource+live.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/18/26.
//

import Foundation
import SwiftData

extension HealthKitStepDataSource where T == HealthKitStepStatisticsQuery {
    static func live() -> Self {
        self.init(stepQuery: HealthKitStepStatisticsQuery())
    }
}

extension NetworkService where Self == URLSessionNetworkService {
    static var live: Self {
        URLSessionNetworkService()
    }
}

extension LocalStorageProvider where Self == SwiftDataStorageProvider {
    static func live(modelContext: ModelContext) -> SwiftDataStorageProvider {
        SwiftDataStorageProvider(modelContext: modelContext)
    }
}
