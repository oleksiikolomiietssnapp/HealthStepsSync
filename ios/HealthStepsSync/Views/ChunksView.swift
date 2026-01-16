//
//  ChunksView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/16/26.
//

import SwiftUI

struct ChunksView: View {
    var chunk: SyncInterval

    var body: some View {
        let intensity = min(Double(chunk.stepCount) / 10000.0, 1.0)
        let color =
            chunk.syncedToServer
            ? Color.blue
            : Color(
                red: 1.0 - intensity * 0.5,
                green: 1.0,
                blue: 1.0 - intensity * 0.5
            )

        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .overlay(
                VStack(alignment: .center, spacing: 0) {
                    Text(chunk.startDate, format: .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))
                    Text(chunk.endDate, format: .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))
                    Text(chunk.stepCount, format: .number.attributed)
                        .font(.caption)
                }
                .font(.caption2)
            )
            .aspectRatio(1, contentMode: .fit)
    }
}
