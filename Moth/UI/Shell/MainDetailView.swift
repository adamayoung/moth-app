//  MainDetailView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

/// Reads the selection here, not in `MainWindowView`, for the reason `RequestDetailView` gives.
struct MainDetailView: View {

    let history: HistoryModel
    let tabs: RequestTabsModel
    let sidebar: SidebarModel

    var body: some View {
        Group {
            if let entry = history.openEntry {
                HistoryEntryPane(id: entry, history: history) { id in
                    history.canOpenRequest(id, in: sidebar.tree)
                }
                .id(entry)
            } else {
                RequestDetailView(tabs: tabs)
            }
        }
        .onChange(of: sidebar.selection) { _, selection in
            if selection != nil {
                history.close()
            }
        }
        .onChange(of: tabs.selectedTab?.id) {
            history.close()
        }
    }

}
