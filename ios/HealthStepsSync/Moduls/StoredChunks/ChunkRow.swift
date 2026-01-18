//
//  ChunkRow.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/18/26.
//

import SwiftUI

struct ChunkRow: View {
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
