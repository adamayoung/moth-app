//  VariableSheet.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

/// A `Grid`, not a `Table`, because a secret's one field spans both value columns and a table cell cannot.
struct VariableSheet: View {

    let title: String
    @State private var table: VariableTableModel
    @FocusState private var focus: VariableField?
    @Environment(\.dismiss) private var dismiss

    init(title: String, table: VariableTableModel) {
        self.title = title
        self._table = State(initialValue: table)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    header
                    ForEach(table.drafts) { draft in
                        VariableRow(draft: draft, table: table, focus: $focus)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("VARIABLES_ADD", action: addVariable)
                    .accessibilityIdentifier("variables.add")
                Spacer()
                Button("VARIABLES_DONE") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("variables.done")
            }
        }
        .padding()
        .frame(minWidth: 780, minHeight: 360)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("variablesSheet")
        .background {
            VariablesObserver(table: table)
        }
        .onChange(of: focus) { previous, _ in
            if let previous {
                Task { await table.commit(previous.rowID) }
            }
        }
        .onDisappear {
            Task { await table.commitAll() }
        }
    }

    private var header: some View {
        GridRow {
            Text("VARIABLES_COLUMN_ENABLED")
            Text("VARIABLES_COLUMN_VARIABLE")
                .gridColumnAlignment(.leading)
            Text("VARIABLES_COLUMN_INITIAL")
            Text("VARIABLES_COLUMN_CURRENT")
            Text("VARIABLES_COLUMN_SECRET")
            Color.clear
                .gridCellUnsizedAxes([.horizontal, .vertical])
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func addVariable() {
        Task {
            if let id = await table.add() {
                focus = .name(id)
            }
        }
    }

}

#Preview("Plain and Secret") {
    if let dataModel = try? DataModel.inMemory(seed: previewWorkspace) {
        let secretStore = InMemorySecretStore()
        VariableSheet(
            title: "Staging",
            table: VariableTableModel(
                scope: .environment(previewEnvironment.id),
                writer: dataModel.writer,
                secretStore: secretStore
            )
        )
        .modelContainer(dataModel.container)
        .task {
            await secretStore.save("hunter2", for: previewAvailableSecret.identifier)
        }
    }
}

private let previewAvailableSecret = SecretReference()

private let previewEnvironment = WorkspaceEnvironment(
    name: "Staging",
    variables: [
        Variable(name: "host", value: .plain(initial: "https://example.com", current: "https://staging.example.com")),
        Variable(name: "token", value: .secret(previewAvailableSecret)),
        Variable(name: "signingKey", value: .secret(SecretReference()), isEnabled: false)
    ]
)

private let previewWorkspace = Workspace(environments: [previewEnvironment])
