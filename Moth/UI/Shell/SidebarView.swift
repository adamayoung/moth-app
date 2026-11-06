//  SidebarView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

struct SidebarView: View {

    @Bindable var model: SidebarModel
    let isSyncedToICloud: Bool

    var body: some View {
        List(selection: $model.selection) {
            Section("SIDEBAR_COLLECTIONS_SECTION") {
                if model.tree.roots.isEmpty {
                    ContentUnavailableView {
                        Text("SIDEBAR_COLLECTIONS_EMPTY")
                    }
                } else {
                    ForEach(model.tree.roots) { node in
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
        .safeAreaBar(edge: .bottom, spacing: 0) {
            if !isSyncedToICloud {
                ICloudSyncOffFooter()
            }
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
        .background {
            SidebarTreeObserver(model: model)
        }
    }

    private var deletionTitle: String {
        String(localized: "SIDEBAR_DELETE_TITLE_\(model.pendingDeletion?.name ?? "")")
    }

}

@ViewBuilder
private func seededSidebar(isSyncedToICloud: Bool) -> some View {
    if let dataModel = try? DataModel.inMemory(seed: SeedData.workspace) {
        SidebarView(model: SidebarModel(writer: dataModel.writer), isSyncedToICloud: isSyncedToICloud)
            .modelContainer(dataModel.container)
            .frame(width: 240, height: 500)
    }
}

#Preview("Synced") {
    seededSidebar(isSyncedToICloud: true)
}

#Preview("iCloud Sync Off") {
    seededSidebar(isSyncedToICloud: false)
}
