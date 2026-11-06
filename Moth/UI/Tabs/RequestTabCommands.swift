//  RequestTabCommands.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import AppKit
import SwiftUI

/// A value, because a `Commands` body cannot observe the model: the view that can publishes what the menu needs.
struct RequestTabCommandContext {

    let tabs: RequestTabsModel
    let hasOpenTabs: Bool

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
                Button("MENU_CLOSE_TAB", action: context.tabs.closeSelected)
                    .keyboardShortcut("w")
            } else {
                Button("MENU_CLOSE", action: closeKeyWindow)
                    .keyboardShortcut("w")
            }

            Button("MENU_CLOSE_WINDOW", action: closeKeyWindow)
                .keyboardShortcut("w", modifiers: [.command, .shift])
        }
    }

    private func closeKeyWindow() {
        NSApp.keyWindow?.performClose(nil)
    }

}
