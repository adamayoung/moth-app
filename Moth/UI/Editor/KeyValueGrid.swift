//  KeyValueGrid.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct KeyValueGrid: View {

    let rows: [KeyValue]
    let identifierPrefix: String
    let addTitle: LocalizedStringKey
    let removeLabel: LocalizedStringKey
    let change: ([KeyValue]) -> Void

    @FocusState private var focusedKey: KeyValue.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                header
                ForEach(rows) { row in
                    gridRow(row)
                }
            }

            Button(addTitle, action: addRow)
                .accessibilityIdentifier("\(identifierPrefix).add")
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

    private func gridRow(_ row: KeyValue) -> some View {
        GridRow {
            Toggle("KEY_VALUE_COLUMN_ENABLED", isOn: binding(row, \.isEnabled))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityIdentifier("\(identifierPrefix).enabled")

            TextField("KEY_VALUE_COLUMN_KEY", text: binding(row, \.key))
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .focused($focusedKey, equals: row.id)
                .accessibilityIdentifier("\(identifierPrefix).key")

            TextField("KEY_VALUE_COLUMN_VALUE", text: binding(row, \.value))
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("\(identifierPrefix).value")

            Button {
                change(rows.filter { $0.id != row.id })
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(removeLabel)
            .accessibilityIdentifier("\(identifierPrefix).remove")
        }
    }

    private func binding<Value>(_ row: KeyValue, _ property: WritableKeyPath<KeyValue, Value>) -> Binding<Value> {
        Binding {
            row[keyPath: property]
        } set: { value in
            change(rows.map { current in
                var changed = current
                if current.id == row.id {
                    changed[keyPath: property] = value
                }
                return changed
            })
        }
    }

    /// Focus moves on the next turn, because the new row's field does not exist until this change has rendered.
    private func addRow() {
        let row = KeyValue(key: "", value: "")
        change(rows + [row])
        Task {
            focusedKey = row.id
        }
    }

}
