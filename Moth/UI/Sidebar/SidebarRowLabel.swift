//  SidebarRowLabel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct SidebarRowLabel<Menu: View>: View {

    let node: TreeNode
    @Bindable var model: SidebarModel
    let tabs: RequestTabsModel
    @ViewBuilder
    let menu: () -> Menu

    /// A row selects from its padding too, so the tap area reaches past the label with no change to the layout. Its
    /// indent stays out of reach, because `NSOutlineView` lays the cell out after it.
    private let rowPadding: CGFloat = 8

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        if model.renaming == node.id {
            renameField
        } else {
            title
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, rowPadding)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded(openRequest))
                .padding(.vertical, -rowPadding)
                .contextMenu { menu() }
                .draggable(SidebarDragItem(id: node.id))
        }
    }

    private var title: some View {
        HStack(spacing: 6) {
            if let method = node.method {
                Text(verbatim: method.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: symbolName)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Text(verbatim: node.name)
                .lineLimit(1)
        }
    }

    /// A click, not a change of selection: arrow keys would open a tab per row, and a row still selected after its tab
    /// closed could not open again.
    private func openRequest() {
        if case .request(let id) = node.id {
            tabs.open(id)
        }
    }

    private var symbolName: String {
        if case .collection = node.id {
            "tray.full"
        } else {
            "folder"
        }
    }

    /// Takes focus from `.task`, because `onAppear` runs before the row is in its window and the request is lost.
    private var renameField: some View {
        TextField("SIDEBAR_RENAME_FIELD_LABEL", text: $model.renameDraft)
            .labelsHidden()
            .focused($isFieldFocused)
            .accessibilityIdentifier("sidebar.renameField")
            .task {
                isFieldFocused = true
            }
            .onSubmit(commit)
            .onExitCommand(perform: model.cancelRename)
            .onChange(of: isFieldFocused) { _, isFocused in
                if !isFocused {
                    commit()
                }
            }
    }

    private func commit() {
        Task { await model.commitRename(of: node.id) }
    }

}
