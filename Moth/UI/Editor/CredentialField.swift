//  CredentialField.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

/// Stays editable with no stored value, unlike a secret variable, because an import saves nothing for an empty
/// credential and there would otherwise be no way to fill it in.
struct CredentialField: View {

    let label: LocalizedStringKey
    let identifier: String
    var isConcealed = true
    let value: SecretValue
    var placeholder: LocalizedStringKey?
    @Binding var text: String

    @State private var isRevealed = false

    var body: some View {
        if value == .loading {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if !isConcealed {
            TextField(label, text: $text, prompt: prompt)
                .labelsHidden()
                .accessibilityIdentifier(identifier)
        } else {
            HStack {
                field
                    .labelsHidden()
                    .accessibilityIdentifier(identifier)

                Button {
                    isRevealed.toggle()
                } label: {
                    Text(isRevealed ? "VARIABLES_SECRET_HIDE" : "VARIABLES_SECRET_SHOW")
                }
                .accessibilityIdentifier("\(identifier)Visibility")
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var field: some View {
        if isRevealed {
            TextField(label, text: $text, prompt: prompt)
        } else {
            SecureField(label, text: $text, prompt: prompt)
        }
    }

    private var prompt: Text? {
        value == .notYetAvailable ? Text("VARIABLES_SECRET_UNAVAILABLE") : placeholder.map { Text($0) }
    }

}
