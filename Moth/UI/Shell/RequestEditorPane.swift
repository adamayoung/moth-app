//  RequestEditorPane.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct RequestEditorPane: View {

    let requestName: String?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("REQUEST_EDITOR_PANE_LABEL")
            .accessibilityIdentifier("requestEditorPane")
    }

    @ViewBuilder
    private var content: some View {
        if let requestName {
            Text(verbatim: requestName)
                .font(.title2)
                .lineLimit(2)
                .padding()
        } else {
            ContentUnavailableView(
                "REQUEST_EDITOR_EMPTY_TITLE",
                systemImage: "doc.text",
                description: Text("REQUEST_EDITOR_EMPTY_DESCRIPTION")
            )
        }
    }

}

#Preview("No Request") {
    RequestEditorPane(requestName: nil)
        .frame(width: 600, height: 300)
}

#Preview("Open Request") {
    RequestEditorPane(requestName: "List Users")
        .frame(width: 600, height: 300)
}
