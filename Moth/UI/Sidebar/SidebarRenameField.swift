//  SidebarRenameField.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct SidebarRenameField: View {

    @Binding var text: String
    let onCommit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    /// Takes focus from `.task`, because `onAppear` runs before the row is in its window and the request is lost.
    var body: some View {
        TextField("SIDEBAR_RENAME_FIELD_LABEL", text: $text)
            .labelsHidden()
            .focused($isFocused)
            .accessibilityIdentifier("sidebar.renameField")
            .task {
                isFocused = true
            }
            .onSubmit(onCommit)
            .onExitCommand(perform: onCancel)
            .onChange(of: isFocused) { _, isFocused in
                if !isFocused {
                    onCommit()
                }
            }
    }

}
