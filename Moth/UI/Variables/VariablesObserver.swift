//  VariablesObserver.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

struct VariablesObserver: View {

    let table: VariableTableModel

    @Query private var rows: [VariableModel]

    init(table: VariableTableModel) {
        self.table = table
        self._rows = Query(VariableModel.inScope(table.scope))
    }

    /// Loads after every delivery, so a secret that arrived since the last look replaces its message.
    var body: some View {
        Color.clear
            .onChange(of: rows.asVariables, initial: true) { _, variables in
                table.variablesDidChange(variables)
                Task { await table.loadSecrets() }
            }
    }

}
