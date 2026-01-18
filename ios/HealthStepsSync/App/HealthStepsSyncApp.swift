//
//  HealthStepsSyncApp.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import OSLog
import SwiftUI
import SwiftData

@main
struct HealthStepsSyncApp: App {
    @Environment(\.healthKitManager) var healthKitManager
    private let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                SyncInterval.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView(healthKitManager: healthKitManager, modelContext: modelContainer.mainContext)
                    .task {
                        do {
                            try await healthKitManager.requestAuthorization()
                        } catch {
                            os_log("Error: %@", error.localizedDescription)
                        }
                    }
            }
        }
        .modelContainer(modelContainer)
    }
}

extension EnvironmentValues {
    @Entry var healthKitManager: HealthKitManager = .live()
}

extension HealthKitManager where T == HealthKitStatisticsQueryProvider {
    static func live() -> Self {
        self.init(healthKitProvider: HealthKitStatisticsQueryProvider())
    }
}

extension HealthKitManager where T == MockStatisticsQueryProvider {
    static func mock() -> Self {
        self.init(healthKitProvider: MockStatisticsQueryProvider())
    }
}
