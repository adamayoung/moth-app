//  TabStripView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

struct TabStripView: View {

    let tabs: RequestTabsModel

    var body: some View {
        let openTabs = tabs.openTabs

        Group {
            if openTabs.isEmpty {
                Color.clear
            } else {
                tabScroller(openTabs)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(.bar, ignoresSafeAreaEdges: [])
        .accessibilityElement(children: openTabs.isEmpty ? .ignore : .contain)
        .accessibilityLabel("TAB_STRIP_LABEL")
        .accessibilityIdentifier("tabStrip")
    }

    /// Only with tabs open, because a horizontal `ScrollView` reaches under the sidebar through the leading safe area,
    /// and
    /// the strip's element measures its children: the empty strip has to keep the width of the panes below it.
    private func tabScroller(_ openTabs: [RequestTab]) -> some View {
        let selected = tabs.selectedTab?.id

        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 2) {
                    ForEach(openTabs) { tab in
                        RequestTabView(
                            tab: tab,
                            isSelected: tab.id == selected,
                            isEdited: tabs.drafts.isEdited(tab.id),
                            select: { tabs.select(tab.id) },
                            close: { tabs.requestClose(tab.id) }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .frame(maxHeight: .infinity)
            }
            .scrollIndicators(.never)
            .onChange(of: selected, initial: true) { _, selected in
                if let selected {
                    proxy.scrollTo(selected)
                }
            }
        }
    }

}

private func openSeededRequests(from tree: CollectionTree, in tabs: RequestTabsModel) {
    let nodes = tree.roots.flatMap(\.children).flatMap { [$0] + $0.children }
    for case .request(let id) in nodes.map(\.id) {
        tabs.open(id)
    }
}

#Preview("No Tabs") {
    TabStripView(tabs: RequestTabsModel(store: .preview, drafts: .preview, responses: .preview, code: .preview))
        .frame(width: 600)
}

#Preview("Open Tabs") {
    let tabs = RequestTabsModel(store: .preview, drafts: .preview, responses: .preview, code: .preview)
    if let dataModel = try? DataModel.inMemory(seed: SeedData.workspace) {
        TabStripView(tabs: tabs)
            .frame(width: 600)
            .background {
                CollectionTreeObserver { snapshot in
                    tabs.collectionDidChange(snapshot)
                    openSeededRequests(from: snapshot.tree, in: tabs)
                }
            }
            .modelContainer(dataModel.container)
    }
}
