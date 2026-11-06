//  RequestTabView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct RequestTabView: View {

    let tab: RequestTab
    let isSelected: Bool
    let isEdited: Bool
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
            .padding(.leading, 14)
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(tab.method.rawValue) \(tab.name)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("requestTab")
        .overlay(alignment: .leading) {
            if isEdited {
                editedDot
            }
        }
    }

    /// Beside the button rather than inside it, because the button's label is how a tab is found, and a click on the
    /// dot still has to select the tab.
    private var editedDot: some View {
        Circle()
            .fill(.secondary)
            .frame(width: 6, height: 6)
            .padding(.leading, 5)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(editedLabel)
            .accessibilityIdentifier("requestTabEdited")
    }

    private var editedLabel: String {
        String(localized: "TAB_EDITED_LABEL_\(tab.name)")
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
        isEdited: false,
        select: {},
        close: {}
    )
    .padding()
}

#Preview("Not Selected") {
    RequestTabView(
        tab: RequestTab(id: UUID(), name: "A Request with a Name Too Long to Fit", method: .delete),
        isSelected: false,
        isEdited: false,
        select: {},
        close: {}
    )
    .padding()
}

#Preview("Edited") {
    RequestTabView(
        tab: RequestTab(id: UUID(), name: "List Users", method: .get),
        isSelected: true,
        isEdited: true,
        select: {},
        close: {}
    )
    .padding()
}
