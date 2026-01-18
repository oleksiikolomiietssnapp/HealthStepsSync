//
//  HealthStepsSyncApp.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import OSLog
import SwiftData
import SwiftUI

@main
struct HealthStepsSyncApp: App {
    @Environment(\.healthKitDataSource) var stepDataSource
    @Environment(\.networkService) var networkService

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
                ContentView(
                    layeringService: LayeringServiceImplementation(
                        stepDataSource: stepDataSource,
                        storageProvider: .live(modelContext: modelContainer.mainContext)
                    ),
                    apiSyncService: SyncServiceImplementation(
                        stepDataSource: stepDataSource,
                        network: networkService,
                        storageProvider: .live(modelContext: modelContainer.mainContext)
                    ),
                    stepDataSource: stepDataSource,
                    networkService: networkService,
                    modelContext: modelContainer.mainContext
                )
                .task {
                    await requestAuthorization()
                }
            }
        }
        .modelContainer(modelContainer)
    }

    private func requestAuthorization() async {
        do {
            try await stepDataSource.requestAuthorization()
        } catch {
            os_log("Error: %@", error.localizedDescription)
        }
    }
}
