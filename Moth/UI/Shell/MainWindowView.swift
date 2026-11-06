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

    init(
        dataModel: DataModel,
        secretStore: any SecretStore,
        activeEnvironment: ActiveEnvironment,
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
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(model: sidebar, environments: environments, isSyncedToICloud: isSyncedToICloud)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            VStack(spacing: 0) {
                TabStripView()
                Divider()
                VSplitView {
                    RequestEditorPane()
                        .frame(minHeight: 160)
                    ResponsePane()
                        .frame(minHeight: 160)
                }
            }
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
        .modelContainer(dataModel.container)
    }

}

#Preview {
    if let dataModel = try? DataModel.inMemory(seed: SeedData.workspace) {
        MainWindowView(
            dataModel: dataModel,
            secretStore: InMemorySecretStore(),
            activeEnvironment: ActiveEnvironment(inMemory: SeedData.workspace.activeEnvironmentID),
            isSyncedToICloud: false
        )
        .frame(width: 1100, height: 720)
    }
}
