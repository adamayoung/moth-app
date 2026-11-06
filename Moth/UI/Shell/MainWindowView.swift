//  MainWindowView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

struct MainWindowView: View {

    private let dataModel: DataModel
    private let isSyncedToICloud: Bool
    @State private var sidebar: SidebarModel
    @State private var environments: EnvironmentsModel
    @State private var tabs: RequestTabsModel

    init(
        dataModel: DataModel,
        secretStore: any SecretStore,
        activeEnvironment: ActiveEnvironment,
        tabStore: RequestTabStore,
        requestDrafts: RequestDrafts,
        isSyncedToICloud: Bool
    ) {
        self.dataModel = dataModel
        self.isSyncedToICloud = isSyncedToICloud
        self.sidebar = SidebarModel(writer: dataModel.writer, secretStore: secretStore)
        self.environments = EnvironmentsModel(
            writer: dataModel.writer,
            secretStore: secretStore,
            activeEnvironment: activeEnvironment
        )
        self.tabs = RequestTabsModel(store: tabStore, drafts: requestDrafts)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(model: sidebar, environments: environments, tabs: tabs, isSyncedToICloud: isSyncedToICloud)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            RequestDetailView(tabs: tabs)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ActiveEnvironmentPicker(environments: environments)
            }
        }
        .background {
            EnvironmentsObserver(model: environments)
        }
        .frame(minWidth: 800, minHeight: 500)
        .background {
            CollectionTreeObserver { snapshot in
                sidebar.treeDidChange(snapshot.tree)
                tabs.collectionDidChange(snapshot)
            }
        }
        .modelContainer(dataModel.container)
    }

}

#Preview {
    if let dataModel = try? DataModel.inMemory(seed: SeedData.workspace) {
        MainWindowView(
            dataModel: dataModel,
            secretStore: InMemorySecretStore(),
            activeEnvironment: ActiveEnvironment(inMemory: SeedData.workspace.activeEnvironmentID),
            tabStore: .preview,
            requestDrafts: RequestDrafts(writer: dataModel.writer),
            isSyncedToICloud: false
        )
        .frame(width: 1100, height: 720)
    }
}
