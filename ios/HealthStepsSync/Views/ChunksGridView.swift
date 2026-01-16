//
//  ChunksGridView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/16/26.
//

import OSLog
import SwiftData
import SwiftUI

struct ChunksGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SyncInterval.startDate, order: .forward, animation: .bouncy) var chunks: [SyncInterval]
    private let columns = 6

    var body: some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: columns)

        LazyVGrid(columns: gridColumns, spacing: 4) {
            ForEach(chunks) { chunk in
                NavigationLink {
                    RawStepView(for: chunk)
                } label: {
                    ChunksView(chunk: chunk)
                }
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    do {
                        try modelContext.delete(model: SyncInterval.self)
                    } catch {
                        os_log("%@", error.localizedDescription)
                    }
                } label: {
                    Text("Delete all")
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Menu {
                    Label("Legend", systemImage: "info.circle")

                    Divider()

                    Text("Green - Stored")
                        .font(.caption)

                    Text("Blue - Synced")
                        .font(.caption)
                } label: {
                    Image(systemName: "questionmark.circle")
                        .imageScale(.large)
                }
            }
        }
    }
}
