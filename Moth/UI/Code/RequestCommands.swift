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
        if case .cancel(let id) = context?.send {
            Button("MENU_CANCEL_SEND") {
                cancelSend(id)
            }
            .keyboardShortcut(".")
        } else {
            Button("MENU_SEND") {
                if let id = context?.send.sendableRequest {
                    withMainWindow { $0.send(id) }
                }
            }
            .keyboardShortcut(.return)
            .disabled(context?.send.sendableRequest == nil)
        }
    }

    /// ⌘. is also the key binding that cancels a sheet, so with one up the key goes on to it.
    private func cancelSend(_ id: Request.ID) {
        if NSApp.keyWindow == NSApp.mainWindow {
            context?.tabs.cancelSend(id)
        } else {
            NSApp.sendAction(#selector(NSResponder.cancelOperation(_:)), to: nil, from: nil)
        }
    }

    private func withSelectedRequest(_ action: (RequestTabsModel, Request.ID) -> Void) {
        if let id = context?.selectedRequest {
            withMainWindow { action($0, id) }
        }
    }

    /// The focused value outlives a sheet or panel taking the keyboard, and nothing may change or open behind one.
    private func withMainWindow(_ action: (RequestTabsModel) -> Void) {
        if let context, NSApp.keyWindow == NSApp.mainWindow {
            action(context.tabs)
        }
    }

}
