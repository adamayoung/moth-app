//  InheritedAuth+Message.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

extension InheritedAuth {

    var message: String {
        switch self {
        case .from(let name): String(localized: "AUTH_INHERITED_FROM_\(name)")
        case .nothing: String(localized: "AUTH_NOTHING_TO_INHERIT")
        }
    }

}
