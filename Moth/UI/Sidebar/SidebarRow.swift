//  SidebarRow.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

/// Drops land on each `ForEach`, not through `.reorderable()`, which strips a nested `List`'s disclosure chevrons.
struct SidebarRow: View {

    let node: TreeNode
    @Bindable var model: SidebarModel
    let tabs: RequestTabsModel

    var body: some View {
        if let container = TreeContainerID(node.id) {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(node.children) { child in
                    SidebarRow(node: child, model: model, tabs: tabs)
                }
                .dropDestination(for: SidebarDragItem.self) { items, offset in
                    drop(items, into: .container(container), atOffset: offset)
                }
            } label: {
                SidebarRowLabel(node: node, model: model, tabs: tabs) {
                    containerMenu(for: container)
                }
                .dropDestination(for: SidebarDragItem.self, isEnabled: true) { items, _ in
                    drop(items, into: .container(container), atOffset: node.children.count)
                }
            }
            .tag(node.id)
        } else {
            SidebarRowLabel(node: node, model: model, tabs: tabs) {
                requestMenu
            }
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
        if case .collection(let id) = container {
            Button("SIDEBAR_VARIABLES") {
                model.presentedVariables = VariableSheetTarget(scope: .collection(id), title: node.name)
            }
        }
        Button("SIDEBAR_AUTHORIZATION") {
            model.presentAuthorization(of: node)
        }
        .disabled(node.auth == nil)
        Divider()
        itemMenu
    }

    @ViewBuilder
    private var requestMenu: some View {
        if case .request(let id) = node.id {
            Button("MENU_COPY_AS_CURL") {
                Task { await tabs.copyCURL(id) }
            }
            Button("MENU_GENERATE_CODE") {
                Task { await tabs.generateCode(id) }
            }
            Divider()
        }
        itemMenu
    }

    @ViewBuilder
    private var itemMenu: some View {
        Button("SIDEBAR_RENAME") {
            Task { await model.beginRename(of: node.id) }
        }
        Button("SIDEBAR_DELETE", role: .destructive) {
            model.requestDeletion(of: node)
        }
    }

    private func drop(_ items: [SidebarDragItem], into parent: SidebarParent, atOffset offset: Int) {
        Task { await model.drop(items.map(\.id), on: parent, atOffset: offset) }
    }

}
