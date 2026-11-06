//  RequestTabView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct RequestTabView: View {

    let tab: RequestTab
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            selectButton
            closeButton
        }
        .frame(maxWidth: 220, minHeight: 28)
        .background(isSelected ? Color.primary.opacity(0.1) : .clear, in: .rect(cornerRadius: 6))
    }

    private var selectButton: some View {
        Button(action: select) {
            HStack(spacing: 6) {
                Text(verbatim: tab.method.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(verbatim: tab.name)
                    .lineLimit(1)
            }
            .padding(.leading, 8)
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(tab.method.rawValue) \(tab.name)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("requestTab")
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(closeLabel)
        .accessibilityLabel(closeLabel)
        .accessibilityIdentifier("requestTabClose")
    }

    private var closeLabel: String {
        String(localized: "TAB_CLOSE_LABEL_\(tab.name)")
    }

}

#Preview("Selected") {
    RequestTabView(
        tab: RequestTab(id: UUID(), name: "List Users", method: .get),
        isSelected: true,
        select: {},
        close: {}
    )
    .padding()
}

#Preview("Not Selected") {
    RequestTabView(
        tab: RequestTab(id: UUID(), name: "A Request with a Name Too Long to Fit", method: .delete),
        isSelected: false,
        select: {},
        close: {}
    )
    .padding()
}
