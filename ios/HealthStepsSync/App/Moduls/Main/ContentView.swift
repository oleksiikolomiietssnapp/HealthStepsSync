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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) var openURL
    @Environment(\.networkService) var networkService

    @State private var viewModel: ContentViewModel

    @Query private var chunks: [SyncInterval]
    @Query(filter: #Predicate<SyncInterval> { !$0.syncedToServer })
    private var unsynchronizedChunks: [SyncInterval]
    private var syncedCount: Int {
        chunks.count - unsynchronizedChunks.count
    }

    init(
        layeringService: some LayeringService,
        apiSyncService: some SyncService,
        stepDataSource: some StepDataSource,
        networkService: some NetworkService,
        modelContext: ModelContext
    ) {

        let chunks = try? modelContext.fetch(FetchDescriptor<SyncInterval>())
        self.viewModel = ContentViewModel(
            chunks: chunks,
            stepDataSource: stepDataSource,
            layeringService: layeringService,
            apiSyncService: apiSyncService,
            network: networkService,
            modelContext: modelContext
        )
    }

    var body: some View {
        Group {
            switch viewModel.healthAuthState {
            case .authorized:
                HealthSyncView(
                    state: viewModel.state,
                    action: {
                        viewModel.performAction(
                            unsynchronizedChunks: unsynchronizedChunks,
                            totalChunks: chunks.count
                        )
                    }
                )
            default:
                UnauthorizedView(
                    title: viewModel.healthAuthState.title,
                    titleSymbolName: viewModel.healthAuthState.systemImage,
                    description: viewModel.healthAuthState.description,
                    buttonText: viewModel.healthAuthState.buttonText,
                    action: actionForStatus()
                )
            }
        }
        .onChange(of: chunks.count) { _, _ in
            if viewModel.state.canUpdateFromPersistence {
                viewModel.state = HealthSyncState(chunks: chunks)
            }
        }
        .onChange(of: unsynchronizedChunks.count) { _, _ in
            if case .syncing = viewModel.state {
                let synced = chunks.count - unsynchronizedChunks.count
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
                Menu {
                    NavigationLink {
                        StoredChunksView()
                    } label: {
                        Label("Stored Chunks", systemImage: "tray.fill")
                    }

                    NavigationLink {
                        SyncedStepsView(networkService: networkService)
                    } label: {
                        Label("Synced Steps", systemImage: "cloud.fill")
                    }
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
        }
    }

    private func actionForStatus() {
        switch viewModel.healthAuthState {
        case .notDetermined:
            viewModel.requestHealthAuthorization()
        case .denied:
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                os_log(.fault, "Can't create URL for HealthKit settings.")
                break
            }
            guard UIApplication.shared.canOpenURL(url) else {
                os_log(.fault, "Can't open HealthKit settings url: %@.", url.path())
                break
            }
            openURL(url)
        case .authorized:
            os_log(.info, "Authorized.")
        case .unavailable:
            os_log(.fault, "HealthKit not available.")
        }
    }
}
