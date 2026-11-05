//  SidebarRow.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct SidebarRow: View {

    let node: TreeNode
    @Bindable var model: SidebarModel

    var body: some View {
        if let container = TreeContainerID(node.id) {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(node.children) { child in
                    SidebarRow(node: child, model: model)
                }
                .reorderable(collectionID: SidebarParent.container(container))
            } label: {
                SidebarRowLabel(node: node, model: model)
                    .contextMenu { containerMenu(for: container) }
                    .dropDestination(for: SidebarDragItem.self, isEnabled: true) { items, _ in
                        drop(items, into: container)
                    }
            }
            .tag(node.id)
        } else {
            SidebarRowLabel(node: node, model: model)
                .contextMenu { itemMenu }
                .tag(node.id)
        }
    }

    private var isExpanded: Binding<Bool> {
        Binding {
            model.expanded.contains(node.id)
        } set: { isExpanded in
            if isExpanded {
                model.expanded.insert(node.id)
            } else {
                model.expanded.remove(node.id)
            }
        }
    }

    @ViewBuilder
    private func containerMenu(for container: TreeContainerID) -> some View {
        Button("MENU_NEW_FOLDER") {
            Task { await model.newFolder(in: container) }
        }
        Button("MENU_NEW_REQUEST") {
            Task { await model.newRequest(in: container) }
        }
        Divider()
        itemMenu
    }

    @ViewBuilder
    private var itemMenu: some View {
        Button("SIDEBAR_RENAME") {
            model.beginRename(of: node.id)
        }
        Button("SIDEBAR_DELETE", role: .destructive) {
            model.requestDeletion(of: node)
        }
    }

    private func drop(_ items: [SidebarDragItem], into container: TreeContainerID) {
        Task {
            for item in items {
                await model.move(item.id, to: .container(container), before: nil)
            }
        }
    }

}
