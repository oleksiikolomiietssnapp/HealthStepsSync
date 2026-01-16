//
//  ContentView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/15/26.
//

import SwiftData
import SwiftUI

enum LoadingChunksState: Equatable {
    case idle
    case loading
    case loaded([SyncInterval])
}

struct ContentView: View {
    @Environment(\.healthKitManager) var healthKitManager
    @Environment(\.modelContext) private var modelContext

    @State private var loadingState: LoadingChunksState = .idle
    @State var task: Task<Void, Never>?

    @State private var startDate: Date?
    @State private var endDate: Date?

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
                    case .loaded(let intervals):
                        HStack(spacing: 0) {
                            Text("Loaded \(intervals.count) chunks in ")
                            Text(startDate!..<endDate!, format: Date.ComponentsFormatStyle(style: .condensedAbbreviated))
                        }
                    }
                }
                .padding()
                Button {
                    switch loadingState {
                    case .idle:
                        startDate = Date()
                        loadingState = .loading
                        task = Task {
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            let service = LayeringService(
                                stepDataProvider: healthKitManager,
                                storageProvider: .mock()
                            )
                            do {
                                let intervals = try await service.performLayering()
                                loadingState = .loaded(intervals)
                                endDate = Date()
                            } catch {
                                print(error.localizedDescription)
                                loadingState = .idle
                                endDate = Date()
                            }
                        }
                    case .loaded:
                        loadingState = .idle
                    case .loading:
                        break
                    }
                } label: {
                    switch loadingState {
                    case .idle:
                        Text("Chunk")
                    case .loading:
                        ProgressView()
                    case .loaded:
                        Text("Reload")
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

#Preview {
    ContentView()
}
