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
                responses.keep(Set(tabs.ids))
            }
        }
    }

    private var tree = CollectionTree.empty
    private let store: RequestTabStore
    let drafts: RequestDrafts
    let responses: RequestResponses
    let code: RequestCodeModel
    let accessTokens: AccessTokens
    var pendingClose: RequestTab?
    /// A count the editor watches, because focus is the view's to move and the menu has no view in reach.
    private(set) var urlFocusRequests = 0

    init(
        store: RequestTabStore,
        drafts: RequestDrafts,
        responses: RequestResponses,
        code: RequestCodeModel,
        accessTokens: AccessTokens = .preview
    ) {
        self.store = store
        self.drafts = drafts
        self.responses = responses
        self.code = code
        self.accessTokens = accessTokens
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

    var canEditURL: Bool {
        selectedEditorDraft != nil
    }

    /// What the selected tab's editor shows, which is nothing for a row that can't be read.
    private var selectedEditorDraft: RequestDraft? {
        guard let id = selectedTab?.id, !drafts.isUnreadable(id) else {
            return nil
        }
        return drafts.draft(for: id)
    }

    func focusURL() {
        if canEditURL {
            urlFocusRequests += 1
        }
    }

    var canCycleTabs: Bool {
        openTabs.count > 1
    }

    func selectNextTab() {
        selectTab(offsetBy: 1)
    }

    func selectPreviousTab() {
        selectTab(offsetBy: -1)
    }

    /// Steps over the tabs on show, so a tab hidden until its row syncs is never selected, and from one goes to an end.
    private func selectTab(offsetBy step: Int) {
        let ids = openTabs.map(\.id)
        guard let selected = tabs.selected, let index = ids.firstIndex(of: selected) else {
            if let end = step > 0 ? ids.first : ids.last {
                select(end)
            }
            return
        }
        select(ids[(index + step + ids.count) % ids.count])
    }

    /// A text field commits as it is torn down with focus, and that text must not land on a tab that has just closed.
    func editDraft(_ id: Request.ID, _ change: (inout RequestDraft) -> Void) {
        if tabs.selected == id {
            drafts.update(id, change)
        }
    }

    var sendCommand: SendCommand {
        guard let id = selectedTab?.id, let draft = selectedEditorDraft else {
            return .unavailable
        }
        if responses.isSending(id) {
            return .cancel(id)
        }
        return draft.hasURL ? .send(id) : .unavailable
    }

    /// Reads the request's OAuth 2.0 token again once the send ends, because the send may have stored a new one.
    @discardableResult
    func send(_ id: Request.ID) -> Task<Void, Never>? {
        guard let draft = drafts.draft(for: id) else {
            return nil
        }
        let sending = responses.send(id, draft: draft, tree: tree)
        guard let reference = tokenReference(sentBy: draft, id: id) else {
            return sending
        }
        return Task { [accessTokens] in
            await sending.value
            await accessTokens.load(reference)
        }
    }

    private func tokenReference(sentBy draft: RequestDraft, id: Request.ID) -> SecretReference? {
        let auth = draft.auth.kind == .inherit ? try? tree.effectiveAuth(of: .request(id)) : draft.auth.requestAuth
        guard case .oauth2(let oauth2) = auth else {
            return nil
        }
        return oauth2.tokenReference
    }

    /// The source is read when the button is pressed, so it carries what the editor holds then.
    func accessTokenControls(for id: Request.ID) -> AccessTokenControls {
        guard let draft = drafts.draft(for: id) else {
            return AccessTokenControls()
        }
        let tree = tree
        return accessTokens.controls(for: draft.auth.oauth2.accessTokenReference) { [drafts] in
            .request(id, drafts.draft(for: id) ?? draft, tree)
        }
    }

    func cancelSend(_ id: Request.ID) {
        responses.cancel(id)
    }

    func copyCURL(_ id: Request.ID) async {
        await code.copyCURL(id, draft: editedDraft(of: id), tree: tree)
    }

    func generateCode(_ id: Request.ID) async {
        await code.presentCode(for: id, draft: editedDraft(of: id), tree: tree)
    }

    /// Edits show in any window, because drafts are shared. A clean draft is `nil`, because a tab that isn't selected
    /// misses deliveries and the store is newer.
    private func editedDraft(of id: Request.ID) -> RequestDraft? {
        drafts.isEdited(id) ? drafts.draft(for: id) : nil
    }

    func requestClose(_ id: Request.ID) {
        if drafts.isEdited(id), let tab = tab(for: id) {
            pendingClose = tab
        } else {
            close(id)
        }
    }

    /// Leaves the tab open if the save failed or text was typed meanwhile, because the tab shows the only copy of it.
    func saveAndClose(_ id: Request.ID) async {
        if await drafts.save(id), !drafts.isEdited(id) {
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
        return RequestTab(
            id: id,
            name: node.name,
            method: method,
            inheritedAuth: tree.inheritedAuth(of: .request(id))
        )
    }

}
