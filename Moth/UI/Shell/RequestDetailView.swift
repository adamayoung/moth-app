//  RequestDetailView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

/// Reads the tabs here, not in `MainWindowView`, because a change there would hand `CollectionTreeObserver` a new
/// closure
/// and walk every row on every tab click.
struct RequestDetailView: View {

    let tabs: RequestTabsModel

    var body: some View {
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
        .focusedSceneValue(
            \.requestTabCommands,
            RequestTabCommandContext(tabs: tabs, hasOpenTabs: !tabs.openTabs.isEmpty)
        )
    }

}

#Preview {
    RequestDetailView(tabs: RequestTabsModel(store: .preview))
        .frame(width: 800, height: 600)
}
