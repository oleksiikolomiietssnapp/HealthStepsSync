//
//  HealthSyncView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import SwiftUI

struct HealthSyncView: View {
    let state: HealthSyncState
    var action: () -> Void

    var body: some View {
        statusView
            .padding()
            .safeAreaBar(edge: .bottom) {
                actionButton
            }
    }

    @ViewBuilder
    private var statusView: some View {
        switch state {
        case .idle:
            Text("Ready to sync health data")
        case .layering:
            ProgressView()
        case .readyToSync:
            Text("Chunks ready to sync")
        case .syncing(let progress):
            VStack {
                ProgressView(value: Double(progress.synced), total: Double(progress.total))
                Text("\(progress.synced) of \(progress.total) synced")
                    .monospaced()
            }
        case .paused(let progress):
            VStack {
                Text("Paused")
                Text("\(progress.synced) of \(progress.total) synced")
                    .monospaced()
            }
        case .completed:
            Label("Sync complete", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let error):
            Label(errorMessage(for: error), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private var actionButton: some View {
        Button(action: handleAction) {
            Text(buttonTitle)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canPerformAction)
    }

    private var buttonTitle: String {
        switch state {
        case .idle: "Start Sync"
        case .layering: "Preparing..."
        case .readyToSync: "Sync to Server"
        case .syncing: "Pause"
        case .paused: "Resume"
        case .completed: "Reset"
        case .failed(let error): error.canRetry ? "Retry" : "Reset"
        }
    }

    private var canPerformAction: Bool {
        if case .layering = state { return false }
        return true
    }

    private func handleAction() {
        action()
    }

    private func errorMessage(for error: HealthSyncState.SyncError) -> String {
        switch error {
        case .layeringFailed(let reason): reason
        case .syncFailed(let reason, _): reason
        case .dataIntegrityError: "Data integrity check failed"
        }
    }
}
