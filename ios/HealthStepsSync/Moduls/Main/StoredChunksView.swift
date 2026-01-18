//
//  StoredChunksView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import SwiftData
import SwiftUI

struct StoredChunksView: View {
    @Query(sort: \SyncInterval.startDate)
    var chunks: [SyncInterval]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            if chunks.isEmpty {
                ContentUnavailableView("No Chunks", systemImage: "tray.fill")
            } else {
                ForEach(chunks) { chunk in
                    ChunkRow(chunk: chunk)
                }
            }
        }
        .navigationTitle("Stored Chunks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    removeAllChunks()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private func removeAllChunks() {
        try? modelContext.delete(model: SyncInterval.self)
    }
}

private struct ChunkRow: View {
    let chunk: SyncInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Steps: \(chunk.stepCount)")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start: \(chunk.startDate.formatted(date: .abbreviated, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("End: \(chunk.endDate.formatted(date: .abbreviated, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: chunk.syncedToServer ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(chunk.syncedToServer ? .green : .gray)

                    Text(chunk.syncedToServer ? "Synced" : "Pending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StoredChunksView()
        .modelContainer(for: SyncInterval.self, inMemory: true)
}
