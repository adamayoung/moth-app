//  MainDetailView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

/// Reads the selection here, not in `MainWindowView`, for the reason `RequestDetailView` gives.
/// The tabs stay in the tree under an open entry, so their commands keep working and ⌘W never closes the window.
struct MainDetailView: View {

    let history: HistoryModel
    let tabs: RequestTabsModel
    let sidebar: SidebarModel

    var body: some View {
        let entry = history.openEntry

        ZStack {
            RequestDetailView(tabs: tabs, isShowing: entry == nil)
                .opacity(entry == nil ? 1 : 0)
                .disabled(entry != nil)
                .accessibilityHidden(entry != nil)

            if let entry {
                HistoryEntryPane(id: entry, history: history) { id in
                    history.canOpenRequest(id, in: sidebar.tree)
                }
                .id(entry)
                .background(.background)
            }
        }
        .background {
            AlternateTabShortcuts(tabs: tabs)
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
