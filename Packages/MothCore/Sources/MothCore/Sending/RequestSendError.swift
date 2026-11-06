//  RequestSendError.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated enum RequestSendError: LocalizedError, Equatable {

    case unreadableInheritedAuth

    public var errorDescription: String? {
        switch self {
        case .unreadableInheritedAuth:
            String(localized: "REQUEST_SEND_UNREADABLE_INHERITED_AUTH", bundle: .module)
        }
    }

}
