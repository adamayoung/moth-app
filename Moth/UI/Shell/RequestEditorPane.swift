//  RequestEditorPane.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct RequestEditorPane: View {

    var body: some View {
        ContentUnavailableView(
            "REQUEST_EDITOR_EMPTY_TITLE",
            systemImage: "doc.text",
            description: Text("REQUEST_EDITOR_EMPTY_DESCRIPTION")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("requestEditorPane")
    }

}

#Preview {
    RequestEditorPane()
        .frame(width: 600, height: 300)
}
