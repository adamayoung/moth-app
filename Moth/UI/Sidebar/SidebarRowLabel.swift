//  SidebarRowLabel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct SidebarRowLabel<Menu: View>: View {

    let node: TreeNode
    @Bindable var model: SidebarModel
    @ViewBuilder
    let menu: () -> Menu

    var body: some View {
        if model.renaming == node.id {
            SidebarRenameField(text: $model.renameDraft, onCommit: commit, onCancel: model.cancelRename)
        } else {
            title
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .contextMenu { menu() }
                .draggable(SidebarDragItem(id: node.id))
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

    private func commit() {
        Task { await model.commitRename(of: node.id) }
    }

}
