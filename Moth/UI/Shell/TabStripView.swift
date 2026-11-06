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
        let selected = tabs.selectedTab?.id

        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 2) {
                    ForEach(openTabs) { tab in
                        RequestTabView(
                            tab: tab,
                            isSelected: tab.id == selected,
                            select: { tabs.select(tab.id) },
                            close: { tabs.close(tab.id) }
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
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(.bar)
        // A `.contain` group measures only its children, so the empty strip needs `.ignore` to keep its own frame.
        .accessibilityElement(children: openTabs.isEmpty ? .ignore : .contain)
        .accessibilityLabel("TAB_STRIP_LABEL")
        .accessibilityIdentifier("tabStrip")
    }

}

private func openSeededRequests(from tree: CollectionTree, in tabs: RequestTabsModel) {
    let nodes = tree.roots.flatMap(\.children).flatMap { [$0] + $0.children }
    for case .request(let id) in nodes.map(\.id) {
        tabs.open(id)
    }
}

#Preview("No Tabs") {
    TabStripView(tabs: RequestTabsModel(store: .preview))
        .frame(width: 600)
}

#Preview("Open Tabs") {
    let tabs = RequestTabsModel(store: .preview)
    if let dataModel = try? DataModel.inMemory(seed: SeedData.workspace) {
        TabStripView(tabs: tabs)
            .frame(width: 600)
            .background {
                CollectionTreeObserver { tree in
                    tabs.treeDidChange(tree)
                    openSeededRequests(from: tree, in: tabs)
                }
            }
            .modelContainer(dataModel.container)
    }
}
