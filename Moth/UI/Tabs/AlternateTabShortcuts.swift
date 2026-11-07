//  AlternateTabShortcuts.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

/// The second pair Safari has, which the Request menu can't list: SwiftUI has no hidden menu item. A sheet takes the
/// window's key status, so neither fires behind one.
struct AlternateTabShortcuts: View {

    let tabs: RequestTabsModel

    var body: some View {
        Group {
            Button("MENU_NEXT_TAB", action: tabs.selectNextTab)
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Button("MENU_PREVIOUS_TAB", action: tabs.selectPreviousTab)
                .keyboardShortcut("[", modifiers: [.command, .shift])
        }
        .focusable(false)
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

}
