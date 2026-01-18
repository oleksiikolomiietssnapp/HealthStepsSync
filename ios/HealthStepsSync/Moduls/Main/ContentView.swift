//
//  ContentView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import OSLog
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.healthKitManager) var healthKitManager
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: ContentViewModel
    private let network: NetworkService

    @Query var chunks: [SyncInterval]
    @Query(filter: #Predicate<SyncInterval> { !$0.syncedToServer })
    var unsyncedChunks: [SyncInterval]
    var syncedCount: Int {
        chunks.count - unsyncedChunks.count
    }

    init(
        healthKitManager: some StepDataProvider,
        modelContext: ModelContext
    ) {
        let network: NetworkService = .live
        self.network = network
        self.viewModel = ContentViewModel(
            chunks: (try? modelContext.fetch(FetchDescriptor<SyncInterval>())) ?? [],
            healthKitManager: healthKitManager,
            layeringService: LayeringServiceImplementation(
                stepDataProvider: healthKitManager,
                storageProvider: .live(modelContext: modelContext)
            ),
            apiSyncService: SyncServiceImplementation(
                health: healthKitManager,
                network: network,
                storageProvider: .live(modelContext: modelContext)
            ),
            network: network,
            modelContext: modelContext
        )
    }

    var body: some View {
        Group {
            switch viewModel.healthAuthState {
            case .authorized:
                VStack {
                    Image(systemName: viewModel.healthAuthState.systemImage)
                        .imageScale(.large)
                        .foregroundStyle(.tint)

                    HealthSyncView(
                        state: viewModel.state,
                        action: {
                            viewModel.performAction(
                                unsyncedChunks: unsyncedChunks,
                                totalChunks: chunks.count
                            )
                        }
                    )
                }
                .padding()

            default:
                ContentUnavailableView {
                    Label(viewModel.healthAuthState.title, systemImage: viewModel.healthAuthState.systemImage)
                } description: {
                    Text(viewModel.healthAuthState.description)
                } actions: {
                    if let buttonText = viewModel.healthAuthState.buttonText {
                        Button(buttonText) {
                            actionForStatus(viewModel.healthAuthState)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .onChange(of: chunks.count) { _, _ in
            if viewModel.state.canUpdateFromPersistence {
                viewModel.state = HealthSyncState(chunks: chunks)
            }
        }
        .onChange(of: unsyncedChunks.count) { _, _ in
            if case .syncing = viewModel.state {
                let synced = chunks.count - unsyncedChunks.count
                viewModel.updateProgress(synced: synced, total: chunks.count)
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                NavigationLink {
                    AdminDataManagementView()
                } label: {
                    Image(systemName: "gearshape.fill")
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                NavigationLink {
                    StoredChunksView()
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
        }
    }

    private func actionForStatus(_ status: HealthKitAuthStatus) {
        switch status {
        case .notDetermined:
            Task {
                do {
                    try await healthKitManager.requestAuthorization()
                } catch {
                    os_log(.error, "HealthKit request authorization error: %@", error.localizedDescription)
                }
            }
        case .denied:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .authorized, .unavailable:
            break
        }
    }
}

extension LocalStorageProvider where Self == SwiftDataStorageProvider {
    static func live(modelContext: ModelContext) -> SwiftDataStorageProvider {
        SwiftDataStorageProvider(modelContext: modelContext)
    }
}

extension LocalStorageProvider where Self == MockStorageProvider {
    static func mock() -> MockStorageProvider {
        MockStorageProvider()
    }
}

