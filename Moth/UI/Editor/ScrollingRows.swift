//  ScrollingRows.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct ScrollingRows<Content: View>: View {

    let focusedRow: UUID?
    @ViewBuilder
    let content: Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: focusedRow) { _, row in
                if let row {
                    proxy.scrollTo(row)
                }
            }
        }
    }

}
