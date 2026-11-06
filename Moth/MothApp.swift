//  MothApp.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import AppKit
import SwiftUI

struct MothApp: App {

    @NSApplicationDelegateAdaptor(MothAppDelegate.self)
    private var appDelegate

    private let dependencies = DependencyProvider.current.dependencies

    var body: some Scene {
        MacScene(dependencies: dependencies)
    }

}

final class MothAppDelegate: NSObject, NSApplicationDelegate {

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        let editedRequestCount = DependencyProvider.current.dependencies.requestDrafts.editedRequestCount
        guard let alert = QuitConfirmationAlert(editedRequestCount: editedRequestCount) else {
            return .terminateNow
        }
        return Self.confirm(alert) ? .terminateNow : .terminateCancel
    }

    private static func confirm(_ alert: QuitConfirmationAlert) -> Bool {
        let modalAlert = NSAlert()
        modalAlert.messageText = alert.title
        modalAlert.informativeText = alert.message
        // The first button takes Return, which must not throw away every draft.
        modalAlert.addButton(withTitle: alert.cancelButton)
        modalAlert.addButton(withTitle: alert.quitButton)
        NSApp.activate()
        return modalAlert.runModal() == .alertSecondButtonReturn
    }

}
