//  ImportCommands.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

/// A value, because a `Commands` body cannot observe the model: the view that can publishes what the menu needs.
struct ImportCommandContext {

    let model: ImportModel
    let canImport: Bool

}

extension FocusedValues {

    @Entry var importCommands: ImportCommandContext?

}

struct ImportCommands: Commands {

    @FocusedValue(\.importCommands) private var context
    @FocusedValue(\.sidebarCommands) private var sidebar

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("MENU_IMPORT") {
                if let model = context?.model {
                    Task { await model.chooseFile() }
                }
            }
            .disabled(context?.canImport != true)

            Button("MENU_IMPORT_CURL") {
                context?.model.beginCurlImport()
            }
            .disabled(context?.canImport != true || sidebar?.importContainer == nil)
        }
    }

}
