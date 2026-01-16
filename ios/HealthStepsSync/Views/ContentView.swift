//
//  ContentView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import SwiftData
import SwiftUI

enum HealthSyncState: Equatable {
    case idle
    case loading
    case loaded
    case storing
    case pauseStoring
    case stored

    init(chunks: [SyncInterval]) {
        if chunks.isEmpty {
            self = .idle
        } else {
            if chunks.first(where: { $0.syncedToServer }) != nil,
               chunks.first(where: { !$0.syncedToServer }) != nil {
                self = .pauseStoring
            } else {
                self = .loaded
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.healthKitManager) var healthKitManager
    @Environment(\.modelContext) private var modelContext
    @Query var chunks: [SyncInterval]

    @State private var loadingState: HealthSyncState
    @State var layeringTask: Task<Void, Never>?

    init(loadingState: HealthSyncState) {
        self.loadingState = loadingState
    }

    var body: some View {
        Group {
            let status = healthKitManager.authStatus
            switch status {
            case .authorized:
                VStack {
                    Image(systemName: status.systemImage)
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    switch loadingState {
                    case .idle:
                        Text(status.title)
                    case .loading:
                        Text("Loading...")
                    case .loaded:
                        VStack {
                            HStack(spacing: 0) {
                                Text("Loaded \(chunks.count) chunks.")
                            }
                            NavigationLink {
                                ScrollView {
                                    ChunksGridView()
                                }
                            } label: {
                                Text("Look at the data")
                            }
                        }
                    case .storing:
                        Text("Started storing")
                    case .pauseStoring:
                        Text("Paused storing")
                    case .stored:
                        Text("Stored")
                    }
                }
                .padding()
                Button {
                    actionForState()
                } label: {
                    switch loadingState {
                    case .idle:
                        Text("Chunk")
                    case .loading:
                        ProgressView()
                    case .loaded:
                        Text("Start storing")
                    case .storing:
                        Text("Pause")
                    case .pauseStoring:
                        Text("Continue")
                    case .stored:
                        Text("Restart")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(loadingState == .loading)

            default:
                ContentUnavailableView {
                    Label(status.title, systemImage: status.systemImage)
                } description: {
                    Text(status.description)
                } actions: {
                    if let buttonText = status.buttonText {
                        Button(buttonText) {
                            actionForStatus(status)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .onAppear {
            if !chunks.isEmpty {
                loadingState = .loaded
            } else {
                loadingState = .idle
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
                    print(error.localizedDescription)
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

    private func actionForState() {
        switch loadingState {
        case .idle:
            loadingState = .loading
            layeringTask = Task {
                let service = LayeringService(
                    stepDataProvider: healthKitManager,
                    storageProvider: .live(modelContext: modelContext)
                )
                do {
                    let _ = try await service.performLayering()
                    loadingState = .loaded
                } catch {
                    print(error.localizedDescription)
                    loadingState = .idle
                }
            }
        case .loaded:
            // TODO: pause the storing
            break
        case .stored:
            loadingState = .idle
        case .loading:
            break
        case .storing:
            // TODO: pause the storing
            break
        case .pauseStoring:
            // TODO: continue the storing
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
