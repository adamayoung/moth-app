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
                    .reorderable(collectionID: SidebarParent.root)
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
        .reorderContainer(for: SidebarDragItem.self, in: SidebarParent.self) { difference in
            let before: TreeNodeID? = switch difference.destination.position {
            case .before(let id): id
            case .end: nil
            }
            move(difference.sources, to: difference.destination.collectionID, before: before)
        }
        .dragContainer(for: SidebarDragItem.self) { (id: TreeNodeID) in
            [SidebarDragItem(id: id)]
        }
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

    private func move(_ sources: [TreeNodeID], to parent: SidebarParent, before: TreeNodeID?) {
        Task {
            for id in sources {
                await model.move(id, to: parent, before: before)
            }
        }
    }

}

#Preview {
    if let dataModel = try? DataModel.inMemory(seed: SeedData.workspace) {
        SidebarView(model: SidebarModel(writer: dataModel.writer))
            .modelContainer(dataModel.container)
            .frame(width: 240, height: 500)
    }
}
