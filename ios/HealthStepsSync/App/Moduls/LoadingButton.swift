//
//  LoadingButton.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import SwiftUI

struct LoadingButton: View {
    enum LoadingButtonState {
        case idl, pressed, finished, failed
        var isDisabled: Bool {
            switch self {
            case .idl, .pressed, .finished:
                return false
            case .failed:
                return true
            }
        }
    }
    @State private var buttonState: LoadingButtonState = .idl
    var title: String
    var action: () async throws -> Void

    var body: some View {
        Button {
            buttonState = .pressed
            Task {
                do {
                    try await action()
                    buttonState = .finished
                } catch {
                    buttonState = .failed
                }
            }
        } label: {
            switch buttonState {
            case .idl:
                Text(title)
            case .pressed:
                ProgressView("...")
            case .finished:
                Text(title)
            case .failed:
                Text(title)
                    .foregroundStyle(Color.red)
            }
        }
        .disabled(buttonState.isDisabled)
    }
}
