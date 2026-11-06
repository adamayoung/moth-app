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
    @State private var tabs: RequestTabsModel

    init(dataModel: DataModel, tabStore: RequestTabStore, isSyncedToICloud: Bool) {
        self.dataModel = dataModel
        self.isSyncedToICloud = isSyncedToICloud
        self.sidebar = SidebarModel(writer: dataModel.writer)
        self.tabs = RequestTabsModel(store: tabStore)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(model: sidebar, tabs: tabs, isSyncedToICloud: isSyncedToICloud)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            VStack(spacing: 0) {
                TabStripView(tabs: tabs)
                Divider()
                VSplitView {
                    RequestEditorPane(requestName: tabs.selectedTab?.name)
                        .frame(minHeight: 160)
                    ResponsePane()
                        .frame(minHeight: 160)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .background {
            CollectionTreeObserver { tree in
                sidebar.treeDidChange(tree)
                tabs.treeDidChange(tree)
            }
        }
        .focusedSceneValue(
            \.requestTabCommands,
            RequestTabCommandContext(tabs: tabs, hasOpenTabs: !tabs.openTabs.isEmpty)
        )
        .modelContainer(dataModel.container)
    }

}

#Preview {
    if let dataModel = try? DataModel.inMemory(seed: SeedData.workspace) {
        MainWindowView(dataModel: dataModel, tabStore: .preview, isSyncedToICloud: false)
            .frame(width: 1100, height: 720)
    }
}
