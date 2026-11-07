//  SidebarCommands.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

/// A value, because a `Commands` body cannot observe the store: the view that can publishes what the menu needs.
struct SidebarCommandContext {

    let model: SidebarModel
    let environments: EnvironmentsModel
    let newItemContainer: TreeContainerID?
    let importContainer: TreeContainerID?

}

extension FocusedValues {

    @Entry var sidebarCommands: SidebarCommandContext?

}

struct SidebarCommands: Commands {

    @FocusedValue(\.sidebarCommands) private var context

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("MENU_NEW_COLLECTION") {
                if let model = context?.model {
                    Task { await model.newCollection() }
                }
            }
            .disabled(context == nil)

            Button("MENU_NEW_FOLDER") {
                if let context, let container = context.newItemContainer {
                    Task { await context.model.newFolder(in: container) }
                }
            }
            .disabled(context?.newItemContainer == nil)

            Button("MENU_NEW_REQUEST") {
                if let context, let container = context.newItemContainer {
                    Task { await context.model.newRequest(in: container) }
                }
            }
            .disabled(context?.newItemContainer == nil)

            Button("MENU_NEW_ENVIRONMENT") {
                if let environments = context?.environments {
                    Task { await environments.newEnvironment() }
                }
            }
            .disabled(context == nil)
        }
    }

}
