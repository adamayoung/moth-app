//  SidebarView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

struct SidebarView: View {

    @Bindable var model: SidebarModel

    @Query private var collections: [CollectionModel]
    @Query private var folders: [FolderModel]
    @Query private var requests: [RequestModel]

    private var tree: CollectionTree {
        CollectionTree(collections: collections, folders: folders, requests: requests)
    }

    var body: some View {
        let tree = tree

        List(selection: $model.selection) {
            Section("SIDEBAR_COLLECTIONS_SECTION") {
                if tree.roots.isEmpty {
                    ContentUnavailableView {
                        Text("SIDEBAR_COLLECTIONS_EMPTY")
                    }
                } else {
                    ForEach(tree.roots) { node in
                        SidebarRow(node: node, model: model)
                    }
                    .dropDestination(for: SidebarDragItem.self) { items, offset in
                        Task { await model.drop(items.map(\.id), on: .root, atOffset: offset) }
                    }
                }
            }

            Section("SIDEBAR_ENVIRONMENTS_SECTION") {
                ContentUnavailableView {
                    Text("SIDEBAR_ENVIRONMENTS_EMPTY")
                }
            }

            Section("SIDEBAR_HISTORY_SECTION") {
                ContentUnavailableView {
                    Text("SIDEBAR_HISTORY_EMPTY")
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("sidebar")
        .alert(deletionTitle, item: $model.pendingDeletion) { deletion in
            Button("SIDEBAR_DELETE_CONFIRM", role: .destructive) {
                Task { await model.confirmDeletion(deletion) }
            }
            Button("SIDEBAR_DELETE_CANCEL", role: .cancel) {}
        } message: { deletion in
            if let count = deletion.requestsToMention {
                Text("SIDEBAR_DELETE_CONTAINER_MESSAGE_\(count)")
            } else {
                Text("SIDEBAR_DELETE_MESSAGE")
            }
        }
        .focusedSceneValue(
            \.sidebarCommands,
            SidebarCommandContext(model: model, newItemContainer: model.newItemContainer)
        )
        .onChange(of: tree, initial: true) { _, newTree in
            model.treeDidChange(newTree)
        }
    }

    private var deletionTitle: String {
        String(localized: "SIDEBAR_DELETE_TITLE_\(model.pendingDeletion?.name ?? "")")
    }

}

#Preview {
    if let dataModel = try? DataModel.inMemory(seed: SeedData.workspace) {
        SidebarView(model: SidebarModel(writer: dataModel.writer))
            .modelContainer(dataModel.container)
            .frame(width: 240, height: 500)
    }
}
