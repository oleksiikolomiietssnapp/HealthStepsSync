//
//  UnauthorizedView.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/18/26.
//

import SwiftUI

struct UnauthorizedView: View {
    private let title: String
    private let titleSymbolName: String
    private let description: String
    private let buttonText: String?
    private let action: () -> Void

    init(title: String, titleSymbolName: String, description: String, buttonText: String?, action: @escaping @autoclosure () -> Void) {
        self.title = title
        self.titleSymbolName = titleSymbolName
        self.description = description
        self.buttonText = buttonText
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: titleSymbolName)
        } description: {
            Text(description)
        } actions: {
            if let buttonText {
                Button(buttonText) {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
