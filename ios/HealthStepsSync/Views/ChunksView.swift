//
//  ChunksView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/16/26.
//

import SwiftUI

struct ChunksView: View {
    @Environment(\.healthKitManager) var healthKitManager
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
                VStack(alignment: .center, spacing: 2) {
                    Text(chunk.startDate, format: .dateTime.month(.twoDigits).day(.twoDigits).year(.twoDigits))
                        .font(.caption2)
                        .foregroundStyle(.black.opacity(0.9))

                    Text(chunk.endDate, format: .dateTime.month(.twoDigits).day(.twoDigits).year(.twoDigits))
                        .font(.caption2)
                        .foregroundStyle(.black.opacity(0.9))

                    Spacer()
                        .frame(height: 4)

                    Text(chunk.stepCount, format: .number)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .padding(4)
            )
            .aspectRatio(1, contentMode: .fit)
    }
}
