//  SidebarView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

struct SidebarView: View {

    @Bindable var model: SidebarModel
    @Bindable var environments: EnvironmentsModel
    let tabs: RequestTabsModel
    @Bindable var history: HistoryModel
    let isSyncedToICloud: Bool

    var body: some View {
        List(selection: $model.selection) {
            Section("SIDEBAR_COLLECTIONS_SECTION") {
                if model.showsEmptyState {
                    ContentUnavailableView {
                        Text("SIDEBAR_COLLECTIONS_EMPTY")
                    }
                } else {
                    ForEach(model.tree.roots) { node in
                        SidebarRow(node: node, model: model, tabs: tabs)
                    }
                    .dropDestination(for: SidebarDragItem.self) { items, offset in
                        Task { await model.drop(items.map(\.id), on: .root, atOffset: offset) }
                    }
                }
            }

            Section("SIDEBAR_ENVIRONMENTS_SECTION") {
                EnvironmentRows(environments: environments) { target in
                    model.presentedVariables = target
                }
            }

            Section {
                HistoryRows(history: history) {
                    model.selection = nil
                }
            } header: {
                Text("SIDEBAR_HISTORY_SECTION")
                    .contextMenu {
                        ClearHistoryButton(history: history)
                    }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("sidebar")
        .onKeyPress(.return, action: openSelectedRequest)
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
        .alert(environmentDeletionTitle, item: $environments.pendingDeletion) { row in
            Button("SIDEBAR_DELETE_CONFIRM", role: .destructive) {
                Task { await environments.confirmDeletion(row) }
            }
            Button("SIDEBAR_DELETE_CANCEL", role: .cancel) {}
        } message: { row in
            if row.variableCount > 0 {
                Text("SIDEBAR_DELETE_ENVIRONMENT_MESSAGE_\(row.variableCount)")
            } else {
                Text("SIDEBAR_DELETE_MESSAGE")
            }
        }
        .alert("HISTORY_CLEAR_ALERT_TITLE", isPresented: $history.isConfirmingClear) {
            Button("HISTORY_CLEAR_CONFIRM", role: .destructive) {
                Task { await history.clear() }
            }
            Button("HISTORY_CLEAR_CANCEL", role: .cancel) {}
        } message: {
            Text("HISTORY_CLEAR_ALERT_MESSAGE")
        }
        .sheet(item: $model.presentedVariables) { target in
            VariableSheet(title: target.title, table: model.variableTable(for: target))
        }
        .sheet(item: $model.presentedAuthorization) { target in
            AuthorizationSheet(
                model: model.authorizationModel(for: target),
                accessTokens: tabs.accessTokens,
                tree: model.tree
            )
        }
        .focusedSceneValue(
            \.sidebarCommands,
            SidebarCommandContext(
                model: model,
                environments: environments,
                newItemContainer: model.newItemContainer,
                newRequestContainer: model.newRequestContainer
            )
        )
    }

    private func openSelectedRequest() -> KeyPress.Result {
        guard model.renaming == nil, case .request(let id) = model.selection else {
            return .ignored
        }
        tabs.open(id)
        return .handled
    }

    private var deletionTitle: String {
        String(localized: "SIDEBAR_DELETE_TITLE_\(model.pendingDeletion?.name ?? "")")
    }

    private var environmentDeletionTitle: String {
        String(localized: "SIDEBAR_DELETE_TITLE_\(environments.pendingDeletion?.name ?? "")")
    }

}

@ViewBuilder
private func seededSidebar(isSyncedToICloud: Bool) -> some View {
    if let dataModel = try? DataModel.inMemory(seed: SeedData.workspace) {
        let secretStore = InMemorySecretStore()
        let model = SidebarModel(writer: dataModel.writer, secretStore: secretStore)
        let environments = EnvironmentsModel(
            writer: dataModel.writer,
            secretStore: secretStore,
            activeEnvironment: ActiveEnvironment(inMemory: nil)
        )
        SidebarView(
            model: model,
            environments: environments,
            tabs: RequestTabsModel(store: .preview, drafts: .preview, responses: .preview, code: .preview),
            history: .preview,
            isSyncedToICloud: isSyncedToICloud
        )
        .background { EnvironmentsObserver(model: environments) }
        .background {
            CollectionTreeObserver { model.treeDidChange($0.tree) }
        }
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
