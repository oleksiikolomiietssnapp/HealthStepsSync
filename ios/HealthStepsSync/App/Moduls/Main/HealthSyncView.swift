//
//  HealthSyncView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import SwiftData
import SwiftUI

struct HealthSyncView: View {
    @Query(sort: \SyncInterval.startDate) var intervals: [SyncInterval]
    let state: HealthSyncState
    var action: () -> Void

    var body: some View {
        VStack {
            stepsCardView
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 2)

            VStack(spacing: 12) {
                actionButton
                    .frame(maxWidth: .infinity)

                statusView
                    .padding()
            }
            .padding(.top, 8)
        }
        .padding()
    }

    @ViewBuilder
    private var stepsCardView: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "figure.walk")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 8) {
                // Total steps
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(intervals.reduce(0) { $0 + $1.stepCount }, format: .number)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("steps")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                // Start date
                if let first = intervals.first {
                    HStack {
                        Text("From:")
                            .fontWeight(.semibold)
                        Text(first.startDate, format: .dateTime.year().month().day())
                            .foregroundColor(.secondary)
                    }
                }

                // End date
                if let last = intervals.last {
                    HStack {
                        Text("To:")
                            .fontWeight(.semibold)
                        Text(last.endDate, format: .dateTime.year().month().day())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch state {
        case .idle:
            Label("Ready to sync health data", systemImage: "figure.walk")
                .foregroundStyle(.secondary)
                .font(.headline)

        case .layering:
            ProgressView("Layering may take few minutes...")
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))

        case .readyToSync:
            Label("Chunks ready to sync", systemImage: "square.stack.3d.up")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

        case .syncing(let progress):
            VStack(spacing: 8) {
                ProgressView(value: Double(progress.synced), total: Double(progress.total))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                Text("\(progress.synced) of \(progress.total) synced")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

        case .paused(let progress):
            VStack(spacing: 4) {
                Label("Paused", systemImage: "pause.circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(progress.synced) of \(progress.total) synced")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

        case .completed:
            Label("Sync complete", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)

        case .failed(let error):
            Label(errorMessage(for: error), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.headline)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        Button(action: handleAction) {
            Text(buttonTitle)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
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
