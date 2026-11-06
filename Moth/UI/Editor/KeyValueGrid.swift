//  KeyValueGrid.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftUI

struct KeyValueGrid<Row: EditableRow>: View {

    let rows: [Row]
    let identifierPrefix: String
    let removeLabel: LocalizedStringKey
    var focusedRow: FocusState<UUID?>.Binding
    let change: ((inout [Row]) -> Void) -> Void

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            header
            ForEach(rows) { row in
                gridRow(row)
            }
        }
    }

    private var header: some View {
        GridRow {
            Text("KEY_VALUE_COLUMN_ENABLED")
            Text("KEY_VALUE_COLUMN_KEY")
                .gridColumnAlignment(.leading)
            Text("KEY_VALUE_COLUMN_VALUE")
                .gridColumnAlignment(.leading)
            Color.clear
                .gridCellUnsizedAxes([.horizontal, .vertical])
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func gridRow(_ row: Row) -> some View {
        GridRow {
            Toggle("KEY_VALUE_COLUMN_ENABLED", isOn: binding(row, \.isEnabled))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(!row.isEditable)
                .accessibilityIdentifier("\(identifierPrefix).enabled")

            TextField("KEY_VALUE_COLUMN_KEY", text: binding(row, \.key))
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .focused(focusedRow, equals: row.id)
                .disabled(!row.isEditable)
                .accessibilityIdentifier("\(identifierPrefix).key")

            if row.isEditable {
                TextField("KEY_VALUE_COLUMN_VALUE", text: binding(row, \.editableText))
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("\(identifierPrefix).value")

                removeButton(for: row)
            } else {
                Text("NOT_SUPPORTED_YET")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("\(identifierPrefix).notSupported")

                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])
            }
        }
    }

    private func removeButton(for row: Row) -> some View {
        Button {
            change { rows in rows.removeAll { $0.id == row.id } }
        } label: {
            Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(removeLabel)
        .accessibilityIdentifier("\(identifierPrefix).remove")
    }

    /// Writes by identifier, not from `rows`, because a field torn down with focus commits late, and a copy of the rows
    /// from its last render would bring back a row that Revert has just removed.
    private func binding<Value>(_ row: Row, _ property: WritableKeyPath<Row, Value>) -> Binding<Value> {
        Binding {
            row[keyPath: property]
        } set: { value in
            change { rows in
                if let index = rows.firstIndex(where: { $0.id == row.id }) {
                    rows[index][keyPath: property] = value
                }
            }
        }
    }

}
