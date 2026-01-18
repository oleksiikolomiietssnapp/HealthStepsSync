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

#Preview {
    StoredChunksView()
        .modelContainer(for: SyncInterval.self, inMemory: true)
}
