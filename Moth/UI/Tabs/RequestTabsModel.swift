//  RequestTabsModel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import Observation

/// One window's tabs, naming requests by identifier, so a tab's name and method come from the tree and follow it.
@Observable
final class RequestTabsModel {

    private var tabs: RequestTabs {
        didSet {
            if tabs != oldValue {
                store.save(tabs)
            }
        }
    }

    private var tree = CollectionTree.empty
    private let store: RequestTabStore

    init(store: RequestTabStore) {
        self.store = store
        self.tabs = store.load()
    }

    var openTabs: [RequestTab] {
        tabs.ids.compactMap(tab)
    }

    var selectedTab: RequestTab? {
        tabs.selected.flatMap(tab)
    }

    func open(_ id: Request.ID) {
        tabs.open(id)
    }

    func select(_ id: Request.ID) {
        tabs.select(id)
    }

    func close(_ id: Request.ID) {
        tabs.close(id)
    }

    func closeSelected() {
        if let selected = tabs.selected {
            close(selected)
        }
    }

    /// Closes on the stored rows, not the tree, which leaves out a row whose parent has not synced yet: that tab hides
    /// until its request returns. A window's first snapshot is the whole store, so this also drops a saved tab.
    func collectionDidChange(_ snapshot: CollectionSnapshot) {
        tree = snapshot.tree
        var remaining = tabs
        for id in tabs.ids where !snapshot.requestIDs.contains(id) {
            remaining.close(id)
        }
        tabs = remaining
    }

    private func tab(for id: Request.ID) -> RequestTab? {
        guard let node = tree.node(.request(id)), let method = node.method else {
            return nil
        }
        return RequestTab(id: id, name: node.name, method: method)
    }

}
