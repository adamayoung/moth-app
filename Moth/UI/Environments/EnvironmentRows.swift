//  EnvironmentRows.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

/// No `.tag` on any row: the sidebar's selection names tree rows, so these open from their context menus.
struct EnvironmentRows: View {

    @Bindable var environments: EnvironmentsModel
    let onEdit: (VariableSheetTarget) -> Void

    var body: some View {
        EnvironmentRowTitle(symbolName: "globe") {
            Text("SIDEBAR_GLOBALS")
        }
        .contextMenu {
            Button("SIDEBAR_EDIT") {
                onEdit(VariableSheetTarget(scope: .globals, title: String(localized: "SIDEBAR_GLOBALS")))
            }
        }

        ForEach(environments.rows) { row in
            if environments.renaming == row.id {
                SidebarRenameField(
                    text: $environments.renameDraft,
                    onCommit: { Task { await environments.commitRename(of: row.id) } },
                    onCancel: environments.cancelRename
                )
            } else {
                EnvironmentRowTitle(symbolName: "square.stack.3d.up") {
                    Text(verbatim: row.name)
                }
                .contextMenu {
                    menu(for: row)
                }
            }
        }
    }

    @ViewBuilder
    private func menu(for row: EnvironmentSummary) -> some View {
        Button("SIDEBAR_EDIT") {
            onEdit(VariableSheetTarget(scope: .environment(row.id), title: row.name))
        }
        Button("SIDEBAR_RENAME") {
            Task { await environments.beginRename(of: row.id) }
        }
        Button("SIDEBAR_DELETE", role: .destructive) {
            environments.requestDeletion(of: row)
        }
    }

}

private struct EnvironmentRowTitle<Title: View>: View {

    let symbolName: String
    @ViewBuilder
    let title: () -> Title

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            title()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

}
