//
//  HealthSyncView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import OSLog
import SwiftData
import SwiftUI

struct HealthSyncView: View {
    @Environment(\.networkService) var networkService
    @Query(sort: \SyncInterval.startDate) var intervals: [SyncInterval]
    let state: HealthSyncState
    var action: () -> Void
    @State private var syncedRecords: Int?

    var body: some View {
        List {
            VStack(spacing: 30) {
                stepsCardView
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 2)

                actionButton

                statusView
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .listRowSeparator(.hidden)
            .animation(.default, value: state)
        }
        .listStyle(.plain)
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var stepsCardView: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "figure.walk")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.tint)
                .padding(.vertical)

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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch state {
            case .idle:
                Label("Ready to sync health data", systemImage: "figure.walk")
                    .foregroundStyle(.secondary)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)

            case .layering:
                ProgressView("Layering may take few minutes...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .frame(maxWidth: .infinity, alignment: .center)

            case .readyToSync:
                Label("\(intervals.count) Chunks ready to sync", systemImage: "square.stack.3d.up")
                    .foregroundStyle(Color.accentColor)
                    .font(.headline)

            case .syncing(let progress):
                ProgressView(value: Double(progress.synced), total: Double(progress.total))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding(.horizontal)
                Text("\(progress.synced) of \(progress.total) synced")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

            case .paused(let progress):
                ProgressView(value: Double(progress.synced), total: Double(progress.total))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding(.horizontal)
                Label("Paused", systemImage: "pause.circle.fill")
                    .foregroundStyle(.yellow)
                    .frame(maxWidth: .infinity, alignment: .center)

            case .completed:
                Label("Sync complete:", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("\(intervals.count) chunks", systemImage: "square.stack.3d.up")
                    .task {
                        do {
                            let stored: GetStepsStoredCountResponse = try await networkService.get(.getSteps)
                            syncedRecords = stored.storedCount
                        } catch {
                            os_log(.error, "%@", error.localizedDescription)
                        }
                    }
                if let syncedRecords {
                    Label("\(syncedRecords) raw step records", systemImage: "square.stack.3d.up.fill")
                        .padding(.leading, 2)
                } else {
                    ProgressView()
                }

            case .failed(let error):
                Label(errorMessage(for: error), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.headline)
            }
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
