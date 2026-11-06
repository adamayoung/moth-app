//  VariableRow.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftUI

enum VariableField: Hashable {

    case name(UUID)
    case initial(UUID)
    case current(UUID)
    case secretValue(UUID)

    var rowID: UUID {
        switch self {
        case .name(let id), .initial(let id), .current(let id), .secretValue(let id): id
        }
    }

}

struct VariableRow: View {

    let draft: VariableDraft
    let table: VariableTableModel
    var focus: FocusState<VariableField?>.Binding

    var body: some View {
        GridRow {
            Toggle("VARIABLES_COLUMN_ENABLED", isOn: isEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityIdentifier("variables.enabled")

            field("VARIABLES_COLUMN_VARIABLE", \.name, focusedAs: .name(draft.id))
                .accessibilityIdentifier("variables.name")

            if let secret = draft.secret {
                SecretValueField(
                    value: secret.value,
                    text: secretText,
                    focus: focus,
                    focusedAs: .secretValue(draft.id)
                )
                .onSubmit(commit)
                .gridCellColumns(2)
            } else {
                field("VARIABLES_COLUMN_INITIAL", \.initial, focusedAs: .initial(draft.id))
                    .accessibilityIdentifier("variables.initial")
                field("VARIABLES_COLUMN_CURRENT", \.current, focusedAs: .current(draft.id))
                    .accessibilityIdentifier("variables.current")
            }

            Toggle("VARIABLES_COLUMN_SECRET", isOn: isSecret)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(!draft.canChangeSecret)
                .accessibilityIdentifier("variables.secret")

            Button {
                Task { await table.remove(draft.id) }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("VARIABLES_REMOVE")
            .accessibilityIdentifier("variables.remove")
        }
    }

    private func field(
        _ label: LocalizedStringKey,
        _ property: WritableKeyPath<VariableDraft, String>,
        focusedAs field: VariableField
    ) -> some View {
        TextField(label, text: text(property))
            .labelsHidden()
            .focused(focus, equals: field)
            .onSubmit(commit)
    }

    private func text(_ property: WritableKeyPath<VariableDraft, String>) -> Binding<String> {
        Binding {
            draft[keyPath: property]
        } set: { text in
            table.update(draft.id) { $0[keyPath: property] = text }
        }
    }

    private var secretText: Binding<String> {
        Binding {
            if case .available(let value) = draft.secret?.value {
                value
            } else {
                ""
            }
        } set: { text in
            table.update(draft.id) { $0.secret?.value = .available(text) }
        }
    }

    private var isEnabled: Binding<Bool> {
        Binding {
            draft.isEnabled
        } set: { isEnabled in
            table.update(draft.id) { $0.isEnabled = isEnabled }
            commit()
        }
    }

    private var isSecret: Binding<Bool> {
        Binding {
            draft.secret != nil
        } set: { isSecret in
            Task { await table.setSecret(isSecret, for: draft.id) }
        }
    }

    private func commit() {
        Task { await table.commit(draft.id) }
    }

}
