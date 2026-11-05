//  EnabledFlags.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

/// Postman writes `enabled` in app-exported environments and `disabled` in collections and
/// Newman's environments, and either can sit on a row. A row is off if either says so.
struct EnabledFlags: Decodable {

    let enabled: Bool?
    let disabled: Bool?

    var isEnabled: Bool {
        enabled != false && disabled != true
    }

}
