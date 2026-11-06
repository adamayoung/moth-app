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
    let drafts: RequestDrafts
    var pendingClose: RequestTab?

    init(store: RequestTabStore, drafts: RequestDrafts) {
        self.store = store
        self.drafts = drafts
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

    /// A text field commits as it is torn down with focus, and that text must not land on a tab that has just closed.
    func editDraft(_ id: Request.ID, _ change: (inout RequestDraft) -> Void) {
        if tabs.selected == id {
            drafts.update(id, change)
        }
    }

    func requestClose(_ id: Request.ID) {
        if drafts.isEdited(id), let tab = tab(for: id) {
            pendingClose = tab
        } else {
            close(id)
        }
    }

    /// A failed save leaves the tab open, because closing it would lose the only copy of the edits.
    func saveAndClose(_ id: Request.ID) async {
        if await drafts.save(id) {
            close(id)
        }
    }

    func discardAndClose(_ id: Request.ID) {
        drafts.revert(id)
        close(id)
    }

    func closeSelected() {
        if let selected = tabs.selected {
            requestClose(selected)
        }
    }

    /// Closes on the stored rows, not the tree, which leaves out a row whose parent has not synced yet: that tab hides
    /// until its request returns. A window's first snapshot is the whole store, so this also drops a saved tab.
    func collectionDidChange(_ snapshot: CollectionSnapshot) {
        tree = snapshot.tree
        drafts.keepRequests(snapshot.requestIDs)
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
