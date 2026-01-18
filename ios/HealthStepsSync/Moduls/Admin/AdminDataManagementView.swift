//
//  AdminDataManagementView.swift
//  HealthStepsSync
//
//  Created for admin data manipulation
//

import SwiftUI

struct AdminDataManagementView: View {
    @Environment(\.healthKitManager) var healthKitManager

    @State private var selectedAction: DataAction?
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var showError = false
    @State private var errorMessage: String?

    enum DataAction: String, CaseIterable {
        case addMonth = "Add 1 Month"
        case addYear = "Add 1 Year"
        case add10Years = "Add 10 Years"
        case removeAll = "Remove All Data"

        var description: String {
            self.rawValue
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                ForEach(DataAction.allCases, id: \.self) { action in
                    Button {
                        Task {
                            await performAction(action)
                        }
                    } label: {
                        HStack {
                            Text(action.description)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if isLoading && selectedAction == action {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding()
                        .background(action == .removeAll ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)
                    .foregroundStyle(action == .removeAll ? .red : .blue)
                }
            }

            if let statusMessage {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(statusMessage)
                            .font(.caption)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                .transition(.opacity)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Data Management")
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func performAction(_ action: DataAction) async {
        isLoading = true
        selectedAction = action
        statusMessage = nil

        do {
            switch action {
            case .addMonth:
                try await healthKitManager.addRealisticStepDataForPastMonth()
                statusMessage = "Added data for past month"

            case .addYear:
                try await healthKitManager.addRealisticStepDataForPastYear()
                statusMessage = "Added data for past year"

            case .add10Years:
                try await healthKitManager.addRealisticStepDataForPast10Years()
                statusMessage = "Added data for past 10 years"

            case .removeAll:
                try await healthKitManager.removeAllStepData()
                statusMessage = "Removed all step data"
            }

            // Auto-dismiss success message after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                statusMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
        selectedAction = nil
    }
}

#Preview {
    NavigationStack {
        AdminDataManagementView()
    }
}
