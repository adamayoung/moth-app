//  MainWindowView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MainWindowView: View {

    private let dataModel: DataModel
    private let isSyncedToICloud: Bool
    @State private var sidebar: SidebarModel
    @State private var environments: EnvironmentsModel
    @State private var tabs: RequestTabsModel
    @State private var imports: ImportModel

    init(
        dataModel: DataModel,
        secretStore: any SecretStore,
        activeEnvironment: ActiveEnvironment,
        tabStore: RequestTabStore,
        requestDrafts: RequestDrafts,
        isSyncedToICloud: Bool,
        importFileSource: ImportFileSource
    ) {
        let writer = dataModel.writer
        let sidebar = SidebarModel(writer: writer, secretStore: secretStore)
        let environments = EnvironmentsModel(
            writer: writer,
            secretStore: secretStore,
            activeEnvironment: activeEnvironment
        )
        self.dataModel = dataModel
        self.isSyncedToICloud = isSyncedToICloud
        self.sidebar = sidebar
        self.environments = environments
        self.tabs = RequestTabsModel(store: tabStore, drafts: requestDrafts)
        self.imports = ImportModel(
            source: importFileSource,
            secretStore: secretStore,
            sidebar: sidebar,
            environments: environments,
            write: { try await writer.create($0) }
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(model: sidebar, environments: environments, tabs: tabs, isSyncedToICloud: isSyncedToICloud)
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    if imports.isImporting {
                        ImportProgressFooter()
                    }
                }
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
        .fileImporter(isPresented: $imports.isChoosingFile, allowedContentTypes: [.json]) { result in
            Task { await imports.fileChosen(result) }
        }
        .sheet(item: $imports.report) { report in
            ImportResultSheet(report: report)
        }
        .focusedSceneValue(
            \.importCommands,
            ImportCommandContext(model: imports, canImport: imports.canImport)
        )
        .modelContainer(dataModel.container)
    }

}

#Preview {
    if let dataModel = try? DataModel.inMemory(seed: SeedData.workspace) {
        let secretStore = InMemorySecretStore()
        MainWindowView(
            dataModel: dataModel,
            secretStore: secretStore,
            activeEnvironment: ActiveEnvironment(inMemory: SeedData.workspace.activeEnvironmentID),
            tabStore: .preview,
            requestDrafts: RequestDrafts(writer: dataModel.writer, secretStore: secretStore),
            isSyncedToICloud: false,
            importFileSource: .panel
        )
        .frame(width: 1100, height: 720)
    }
}
