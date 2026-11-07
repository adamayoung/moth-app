//  MainWindowView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import HTTPKit
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
    @State private var cookies: CookiesModel

    init(
        dataModel: DataModel,
        secretStore: any SecretStore,
        cookieJars: CookieJars,
        transport: any HTTPTransport,
        activeEnvironment: ActiveEnvironment,
        tabStore: RequestTabStore,
        requestDrafts: RequestDrafts,
        isSyncedToICloud: Bool,
        importFileSource: ImportFileSource,
        clipboard: Clipboard
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
        let tabs = RequestTabsModel(
            store: tabStore,
            drafts: requestDrafts,
            responses: RequestResponses(
                dataModel: dataModel,
                transport: transport,
                secretStore: secretStore,
                cookieJars: cookieJars,
                activeEnvironment: activeEnvironment
            ),
            code: RequestCodeModel(
                dataModel: dataModel,
                activeEnvironment: activeEnvironment,
                clipboard: clipboard
            )
        )
        self.tabs = tabs
        self.cookies = CookiesModel(dataModel: dataModel, cookieJars: cookieJars)
        self.imports = ImportModel(
            source: importFileSource,
            secretStore: secretStore,
            sidebar: sidebar,
            environments: environments,
            write: { try await writer.create($0) },
            createRequest: { try await writer.createRequest($0, in: $1) },
            openRequest: { tabs.open($0) }
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
        .sheet(isPresented: $imports.isEnteringCurl) {
            CurlImportSheet(model: imports)
        }
        .sheet(item: $imports.report) { report in
            ImportResultSheet(report: report)
        }
        .sheet(isPresented: $cookies.isPresented) {
            CookiesSheet(model: cookies)
        }
        .focusedSceneValue(\.cookiesModel, cookies)
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
            cookieJars: CookieJars(writer: dataModel.writer, secretStore: secretStore),
            transport: StubHTTPTransport(),
            activeEnvironment: ActiveEnvironment(inMemory: SeedData.workspace.activeEnvironmentID),
            tabStore: .preview,
            requestDrafts: RequestDrafts(writer: dataModel.writer, secretStore: secretStore),
            isSyncedToICloud: false,
            importFileSource: .panel,
            clipboard: .general
        )
        .frame(width: 1100, height: 720)
    }
}
