//  StoreFailureApp.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import AppKit
import SwiftUI

/// A SwiftUI `.alert` needs a window to attach to, and this alert appears before any window.
struct StoreFailureApp: App {

    @NSApplicationDelegateAdaptor(StoreFailureAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }

}

final class StoreFailureAppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_: Notification) {
        if case .storeFailure(let alert) = DependencyProvider.currentOutcome {
            Self.show(alert)
        }
        NSApp.terminate(nil)
    }

    private static func show(_ alert: StoreFailureAlert) {
        let modalAlert = NSAlert()
        modalAlert.messageText = alert.title
        modalAlert.informativeText = alert.message
        modalAlert.addButton(withTitle: alert.quitButton)
        modalAlert.runModal()
    }

}
