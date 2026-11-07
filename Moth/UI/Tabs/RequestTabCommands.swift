//  RequestTabCommands.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import AppKit
import MothCore
import SwiftUI

/// A value, because a `Commands` body cannot observe the model: the view that can publishes what the menu needs.
struct RequestTabCommandContext {

    let tabs: RequestTabsModel
    let hasOpenTabs: Bool
    let selectedRequest: Request.ID?
    let savableRequest: Request.ID?
    let send: SendCommand
    let canEditURL: Bool
    let canCycleTabs: Bool

}

extension RequestTabCommandContext {

    /// Under a history entry the tabs stay live for Close Tab and moving between tabs, but nothing may act on a request
    /// the person can't see.
    init(tabs: RequestTabsModel, isShowing: Bool) {
        let selected = tabs.selectedTab
        self.init(
            tabs: tabs,
            hasOpenTabs: !tabs.openTabs.isEmpty,
            selectedRequest: selected?.id,
            savableRequest: selected.flatMap { tabs.drafts.canSave($0.id) ? $0.id : nil },
            send: isShowing ? tabs.sendCommand : .unavailable,
            canEditURL: isShowing && tabs.canEditURL,
            canCycleTabs: tabs.canCycleTabs
        )
    }

}

extension FocusedValues {

    @Entry var requestTabCommands: RequestTabCommandContext?

}

struct RequestTabCommands: Commands {

    @FocusedValue(\.requestTabCommands) private var context

    /// `.saveItem` holds the system's Close, so this also has to close a window that has no tabs. A disabled Close Tab
    /// would swallow ⌘W there.
    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            if let context, context.hasOpenTabs {
                Button("MENU_CLOSE_TAB") {
                    closeSelectedTab(in: context.tabs)
                }
                .keyboardShortcut("w")
            } else {
                Button("MENU_CLOSE", action: closeKeyWindow)
                    .keyboardShortcut("w")
            }

            Button("MENU_CLOSE_WINDOW", action: closeKeyWindow)
                .keyboardShortcut("w", modifiers: [.command, .shift])

            Divider()

            Button("MENU_SAVE") {
                withSavableRequest { tabs, id in
                    Task { await tabs.drafts.save(id) }
                }
            }
            .keyboardShortcut("s")
            .disabled(context?.savableRequest == nil)

            Button("MENU_REVERT_TO_SAVED") {
                withSavableRequest { tabs, id in
                    tabs.drafts.revert(id)
                }
            }
            .disabled(context?.savableRequest == nil)
        }
    }

    /// The focused value outlives a sheet or panel taking the keyboard, and a draft must not change behind one.
    private func withSavableRequest(_ action: (RequestTabsModel, Request.ID) -> Void) {
        if let context, let id = context.savableRequest, NSApp.keyWindow == NSApp.mainWindow {
            action(context.tabs, id)
        }
    }

    /// The focused value outlives a sheet or panel taking the keyboard, and a tab must not close behind one.
    private func closeSelectedTab(in tabs: RequestTabsModel) {
        if NSApp.keyWindow == NSApp.mainWindow {
            tabs.closeSelected()
        } else {
            closeKeyWindow()
        }
    }

    private func closeKeyWindow() {
        NSApp.keyWindow?.performClose(nil)
    }

}
