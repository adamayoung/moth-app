//  QuitConfirmationAlert.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation

struct QuitConfirmationAlert {

    let title = String(localized: "QUIT_ALERT_TITLE")
    let message: String
    let quitButton = String(localized: "QUIT_ALERT_QUIT")
    let cancelButton = String(localized: "QUIT_ALERT_CANCEL")

    init?(editedRequestCount count: Int) {
        guard count > 0 else {
            return nil
        }
        self.message = String(localized: "QUIT_ALERT_MESSAGE_\(count)")
    }

}
