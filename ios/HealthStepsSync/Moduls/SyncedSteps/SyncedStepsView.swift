//
//  SyncedStepsView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/18/26.
//

import Observation
import SwiftUI

@MainActor
@Observable
final class SyncedStepsViewModel {
    @ObservationIgnored private let networkService: NetworkService

    var storedCount: Int = 0
    var isLoading = false
    var errorMessage: String?

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func fetchSteps() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: GetStepsStoredCountResponse = try await networkService.get(.getSteps)
            storedCount = response.storedCount
        } catch {
            errorMessage = error.localizedDescription
            storedCount = 0
        }

        isLoading = false
    }
}

struct SyncedStepsView: View {
    @State private var viewModel: SyncedStepsViewModel

    init(networkService: NetworkService) {
        let vm = SyncedStepsViewModel(networkService: networkService)
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text(errorMessage)
                )
            } else if viewModel.storedCount == 0 {
                ContentUnavailableView("No Synced Steps", systemImage: "tray.fill")
            } else {
                ContentUnavailableView("TBD. Raw data list goes here.", systemImage: "clock")
                // List(viewModel.steps, id: \.uuid) { step in
                //     RawStepRow(sample: step)
                // }
            }
        }
        .navigationTitle("\(viewModel.storedCount) records")
        .navigationTitle("Synced Steps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task {
                        await viewModel.fetchSteps()
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.fetchSteps()
        }
    }
}

#Preview {
    NavigationStack {
        SyncedStepsView(networkService: .live)
    }
}
