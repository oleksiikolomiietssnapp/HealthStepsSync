//
//  StoredChunksView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import SwiftData
import SwiftUI

struct StoredChunksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.networkService) private var networkService

    @Query(sort: \SyncInterval.startDate)
    var chunks: [SyncInterval]

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
        .navigationTitle("\(chunks.count) records")
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
        Task {
            try? await networkService.delete(.deleteSteps)
        }
    }
}

#Preview {
    StoredChunksView()
        .modelContainer(for: SyncInterval.self, inMemory: true)
}
