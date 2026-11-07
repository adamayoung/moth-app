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
            sendButton

            Button("MENU_EDIT_URL") {
                withMainWindow { $0.focusURL() }
            }
            .keyboardShortcut("l")
            .disabled(context?.canEditURL != true)

            Divider()

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

            Divider()

            Button("MENU_NEXT_TAB") {
                withMainWindow { $0.selectNextTab() }
            }
            .keyboardShortcut(.tab, modifiers: .control)
            .disabled(context?.canCycleTabs != true)

            Button("MENU_PREVIOUS_TAB") {
                withMainWindow { $0.selectPreviousTab() }
            }
            .keyboardShortcut(.tab, modifiers: [.control, .shift])
            .disabled(context?.canCycleTabs != true)
        }
    }

    @ViewBuilder
    private var sendButton: some View {
        switch context?.send {
        case .cancel(let id):
            Button("MENU_CANCEL_SEND") {
                withMainWindow { $0.cancelSend(id) }
            }
            .keyboardShortcut(".")
        case .send(let id):
            Button("MENU_SEND") {
                withMainWindow { $0.send(id) }
            }
            .keyboardShortcut(.return)
        case .unavailable, nil:
            Button("MENU_SEND") {}
                .keyboardShortcut(.return)
                .disabled(true)
        }
    }

    /// The focused value outlives a sheet or panel taking the keyboard, and a second sheet must not open behind one.
    private func withSelectedRequest(_ action: (RequestTabsModel, Request.ID) -> Void) {
        if let context, let id = context.selectedRequest, NSApp.keyWindow == NSApp.mainWindow {
            action(context.tabs, id)
        }
    }

    /// The focused value outlives a sheet or panel taking the keyboard, and the tabs must not change behind one.
    private func withMainWindow(_ action: (RequestTabsModel) -> Void) {
        if let context, NSApp.keyWindow == NSApp.mainWindow {
            action(context.tabs)
        }
    }

}
