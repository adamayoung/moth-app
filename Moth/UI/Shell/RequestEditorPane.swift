//  RequestEditorPane.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct RequestEditorPane: View {

    let tab: RequestTab?
    let drafts: RequestDrafts
    let edit: (Request.ID, (inout RequestDraft) -> Void) -> Void
    var isSending = false
    var send: (Request.ID) -> Void = { _ in }
    var cancelSend: (Request.ID) -> Void = { _ in }
    var urlFocusRequests = 0
    var accessToken: (Request.ID) -> AccessTokenControls = { _ in AccessTokenControls() }

    @State private var section = RequestEditorSection.params

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("REQUEST_EDITOR_PANE_LABEL")
            .accessibilityIdentifier("requestEditorPane")
    }

    @ViewBuilder
    private var content: some View {
        if let tab {
            editor(for: tab)
        } else {
            ContentUnavailableView(
                "REQUEST_EDITOR_EMPTY_TITLE",
                systemImage: "doc.text",
                description: Text("REQUEST_EDITOR_EMPTY_DESCRIPTION")
            )
        }
    }

    /// Identified by the tab, so a field that holds focus can't write its text into the next request's draft.
    @ViewBuilder
    private func editor(for tab: RequestTab) -> some View {
        if drafts.isUnreadable(tab.id) {
            ContentUnavailableView(
                "REQUEST_EDITOR_UNREADABLE_TITLE",
                systemImage: "exclamationmark.triangle",
                description: Text("REQUEST_EDITOR_UNREADABLE_DESCRIPTION")
            )
        } else if let draft = drafts.draft(for: tab.id) {
            RequestEditorForm(
                name: tab.name,
                draft: draft,
                inheritedAuth: tab.inheritedAuth,
                section: $section,
                credential: { drafts.credential($0, in: tab.id) },
                loadCredential: { await drafts.loadCredential($0, in: tab.id) },
                update: { change in edit(tab.id, change) },
                isSending: isSending,
                send: { send(tab.id) },
                cancelSend: { cancelSend(tab.id) },
                urlFocusRequests: urlFocusRequests,
                accessToken: accessToken(tab.id)
            )
            .id(tab.id)
        }
    }

}

#Preview("No Request") {
    let drafts = RequestDrafts.preview

    return RequestEditorPane(tab: nil, drafts: drafts, edit: drafts.update)
        .frame(width: 600, height: 300)
}

#Preview("Open Request") {
    let request = Request(
        name: "List Users",
        urlTemplate: "{{host}}/users/:id",
        queryParameters: [
            KeyValue(key: "limit", value: "10"),
            KeyValue(key: "offset", value: "0", isEnabled: false)
        ],
        pathParameters: [KeyValue(key: "id", value: "42")]
    )
    let drafts = RequestDrafts.preview
    drafts.savedRequestDidChange(request)

    return RequestEditorPane(
        tab: RequestTab(id: request.id, name: request.name, method: .get),
        drafts: drafts,
        edit: drafts.update
    )
    .frame(width: 600, height: 300)
}

#Preview("Unreadable Request") {
    let tab = RequestTab(id: UUID(), name: "List Users", method: .get)
    let drafts = RequestDrafts.preview
    drafts.savedRequestIsUnreadable(tab.id)

    return RequestEditorPane(tab: tab, drafts: drafts, edit: drafts.update)
        .frame(width: 600, height: 300)
}
