//
//  RawStepRow.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/18/26.
//

import SwiftUI

struct RawStepRow: View {
    let sample: APIStepSample

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon for device
            Image(systemName: "\(sample.sourceDeviceName?.lowercased(), default: "questionmark")")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                // Step count
                Text("\(sample.count) steps")
                    .font(.headline)

                // Start → End
                Text("\(formatDateInterval(start: sample.startDate, end: sample.endDate))")
                    .font(.caption)
                    .foregroundStyle(.primary)

                Text("Source: \(sample.sourceBundleId.split(separator: ".").last , default: "-")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        }
    }

    private func formatDateInterval(start isoStart: String, end isoEnd: String) -> String {
        let isoFormatter = ISO8601DateFormatter.api

        guard let startDate = isoFormatter.date(from: isoStart),
            let endDate = isoFormatter.date(from: isoEnd)
        else {
            return "\(isoStart)\n\(isoEnd)"  // fallback
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: endDate)

        return "\(startString) → \(endString)"
    }
}
