//
//  StepSampleData.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import Foundation
import HealthKit

/// Unified sample data structure (works for both HealthKit and mock)
protocol StepSampleData {
    var uuid: UUID { get }
    var startDate: Date { get }
    var endDate: Date { get }
    var count: Int { get }
    var sourceBundleId: String { get }
    var sourceDeviceName: String? { get }
}

extension HKQuantitySample: StepSampleData {
    var count: Int { Int(quantity.doubleValue(for: .count())) }
    var sourceBundleId: String { sourceRevision.source.bundleIdentifier }
    var sourceDeviceName: String? { device?.name }
}
