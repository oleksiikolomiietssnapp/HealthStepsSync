//
//  RawStepView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/16/26.
//

import OSLog
import SwiftUI

struct RawStepView: View {
    @Environment(\.healthKitManager) var healthKitManager
    @State var stepsRawData: [StepSampleData]
    private var chunk: SyncInterval

    init(for chunk: SyncInterval) {
        self.stepsRawData = []
        self.chunk = chunk
    }

    var body: some View {
        List(stepsRawData, id: \.uuid) { data in
            HStack {
                HStack {
                    Image(systemName: iconForDevice(data.sourceDeviceName))
                        .foregroundStyle(Color.accentColor)
                    Text(data.count, format: .number.attributed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                let date = data.endDate

                Text("\(date.formatted(.dateTime.month(.abbreviated).day())) at \(date.formatted(.dateTime.hour(.twoDigits(amPM: .wide)).minute(.twoDigits)))")
            }
        }
        .task {
            do {
                stepsRawData = try await healthKitManager.fetchStepSamples(from: chunk.startDate, to: chunk.endDate)
            } catch {
                os_log(.error, "%@", error.localizedDescription)
            }
        }
    }

    private func iconForDevice(_ model: String?) -> String {
        guard let model,
            let device = HealthDeviceModel(rawValue: model)
        else {
            return "iphone.gen1"
        }

        switch device {
        case .iPhone: return "iphone"
        case .watch: return "applewatch"
        }
    }
}


enum HealthDeviceModel: String, CaseIterable {
    case iPhone = "iPhone"
    case watch = "Watch"

    static var random: HealthDeviceModel {
        HealthDeviceModel.allCases.randomElement() ?? .iPhone
    }
}
