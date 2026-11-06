//  RequestEditorPane.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct RequestEditorPane: View {

    let tab: RequestTab?
    let drafts: RequestDrafts

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
            RequestEditorForm(name: tab.name, draft: draft, section: $section) { change in
                drafts.update(tab.id, change)
            }
            .id(tab.id)
        }
    }

}

#Preview("No Request") {
    RequestEditorPane(tab: nil, drafts: RequestDrafts(save: { _, _ in }))
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
    let drafts = RequestDrafts(save: { _, _ in })
    drafts.savedRequestDidChange(request)

    return RequestEditorPane(tab: RequestTab(id: request.id, name: request.name, method: .get), drafts: drafts)
        .frame(width: 600, height: 300)
}

#Preview("Unreadable Request") {
    let tab = RequestTab(id: UUID(), name: "List Users", method: .get)
    let drafts = RequestDrafts(save: { _, _ in })
    drafts.savedRequestIsUnreadable(tab.id)

    return RequestEditorPane(tab: tab, drafts: drafts)
        .frame(width: 600, height: 300)
}
