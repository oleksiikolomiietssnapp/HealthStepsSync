//
//  EnvironmentValues+Entries.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/18/26.
//

import SwiftUI

extension EnvironmentValues {
    @Entry var healthKitDataSource: HealthKitStepDataSource = .live()
    @Entry var networkService: NetworkService = .live
}
