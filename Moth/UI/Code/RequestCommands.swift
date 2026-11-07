//  RequestCommands.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import AppKit
import MothCore
import SwiftUI

struct RequestCommands: Commands {

    @FocusedValue(\.requestTabCommands) private var context

    var body: some Commands {
        CommandMenu("MENU_REQUEST") {
            Button("MENU_COPY_AS_CURL") {
                withSelectedRequest { tabs, id in
                    Task { await tabs.copyCURL(id) }
                }
            }
            .disabled(context?.selectedRequest == nil)

            Button("MENU_GENERATE_CODE") {
                withSelectedRequest { tabs, id in
                    Task { await tabs.generateCode(id) }
                }
            }
            .disabled(context?.selectedRequest == nil)
        }
    }

    /// The focused value outlives a sheet or panel taking the keyboard, and a second sheet must not open behind one.
    private func withSelectedRequest(_ action: (RequestTabsModel, Request.ID) -> Void) {
        if let context, let id = context.selectedRequest, NSApp.keyWindow == NSApp.mainWindow {
            action(context.tabs, id)
        }
    }

}
