//  TabStripView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct TabStripView: View {

    var body: some View {
        Rectangle()
            .fill(.bar)
            .frame(height: 36)
            .accessibilityElement()
            .accessibilityLabel("TAB_STRIP_LABEL")
            .accessibilityIdentifier("tabStrip")
    }

}

#Preview {
    TabStripView()
        .frame(width: 600)
}
