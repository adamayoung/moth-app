//  StoreFailureAlert.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

struct StoreFailureAlert {

    let title = String(localized: "STORE_FAILURE_ALERT_TITLE")
    let message: String
    let quitButton = String(localized: "STORE_FAILURE_ALERT_QUIT")

    init(cause: any Error) {
        self.message = if cause is UnknownStoreSchemaError {
            String(localized: "STORE_FAILURE_ALERT_NEWER_SCHEMA_MESSAGE")
        } else {
            String(localized: "STORE_FAILURE_ALERT_MESSAGE")
        }
    }

}
