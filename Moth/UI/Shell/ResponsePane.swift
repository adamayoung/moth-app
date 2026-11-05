//  ResponsePane.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct ResponsePane: View {

    var body: some View {
        ContentUnavailableView(
            "RESPONSE_EMPTY_TITLE",
            systemImage: "arrow.down.doc",
            description: Text("RESPONSE_EMPTY_DESCRIPTION")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("responsePane")
    }

}

#Preview {
    ResponsePane()
        .frame(width: 600, height: 300)
}
