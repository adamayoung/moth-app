//  SidebarRowLabel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct SidebarRowLabel: View {

    let node: TreeNode
    let model: SidebarModel

    @State private var draft = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        if model.renaming == node.id {
            renameField
        } else {
            title
        }
    }

    private var title: some View {
        HStack(spacing: 6) {
            if let method = node.method {
                Text(verbatim: method.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: symbolName)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Text(verbatim: node.name)
                .lineLimit(1)
        }
    }

    private var symbolName: String {
        if case .collection = node.id {
            "tray.full"
        } else {
            "folder"
        }
    }

    private var renameField: some View {
        TextField("SIDEBAR_RENAME_FIELD_LABEL", text: $draft)
            .labelsHidden()
            .focused($isFieldFocused)
            .accessibilityIdentifier("sidebar.renameField")
            .onAppear {
                draft = node.name
                isFieldFocused = true
            }
            .onSubmit(commit)
            .onExitCommand(perform: model.cancelRename)
            .onChange(of: isFieldFocused) { _, isFocused in
                if !isFocused {
                    commit()
                }
            }
    }

    private func commit() {
        Task { await model.commitRename(of: node.id, to: draft) }
    }

}
