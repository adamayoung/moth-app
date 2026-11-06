//  SecretValueField.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct SecretValueField: View {

    let value: SecretValue
    @Binding var text: String
    var focus: FocusState<VariableField?>.Binding
    let focusedAs: VariableField

    @State private var isRevealed = false

    var body: some View {
        switch value {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .notYetAvailable:
            Text("VARIABLES_SECRET_UNAVAILABLE")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("variables.secretUnavailable")
        case .available:
            HStack {
                field
                    .labelsHidden()
                    .focused(focus, equals: focusedAs)
                    .accessibilityIdentifier("variables.secretValue")
                Button {
                    isRevealed.toggle()
                } label: {
                    Text(isRevealed ? "VARIABLES_SECRET_HIDE" : "VARIABLES_SECRET_SHOW")
                }
                .accessibilityIdentifier("variables.secretVisibility")
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        if isRevealed {
            TextField("VARIABLES_SECRET_VALUE_LABEL", text: $text)
        } else {
            SecureField("VARIABLES_SECRET_VALUE_LABEL", text: $text)
        }
    }

}
