//  MainWindowView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

struct MainWindowView: View {

    private let dataModel: DataModel
    @State private var sidebar: SidebarModel

    init(dataModel: DataModel) {
        self.dataModel = dataModel
        self.sidebar = SidebarModel(writer: dataModel.writer)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(model: sidebar)
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
        .frame(minWidth: 800, minHeight: 500)
        .modelContainer(dataModel.container)
    }

}

#Preview {
    if let dataModel = try? DataModel.inMemory(seed: SeedData.workspace) {
        MainWindowView(dataModel: dataModel)
            .frame(width: 1100, height: 720)
    }
}
