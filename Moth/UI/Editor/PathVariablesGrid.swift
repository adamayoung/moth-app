//  PathVariablesGrid.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct PathVariablesGrid: View {

    let rows: [KeyValue]
    let setValue: (String, KeyValue.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REQUEST_EDITOR_PATH_VARIABLES")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                ForEach(rows) { row in
                    GridRow {
                        Text(verbatim: row.key)
                            .accessibilityIdentifier("pathVariables.name")

                        TextField("KEY_VALUE_COLUMN_VALUE", text: value(of: row))
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("pathVariables.value")
                    }
                }
            }
        }
    }

    private func value(of row: KeyValue) -> Binding<String> {
        Binding {
            row.value
        } set: { value in
            setValue(value, row.id)
        }
    }

}
