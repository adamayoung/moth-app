//  RequestSendError.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated enum RequestSendError: LocalizedError, Equatable {

    case requestNotFound
    case unreadableInheritedAuth

    public var errorDescription: String? {
        switch self {
        case .requestNotFound:
            String(localized: "REQUEST_SEND_NOT_FOUND", bundle: .module)
        case .unreadableInheritedAuth:
            String(localized: "REQUEST_SEND_UNREADABLE_INHERITED_AUTH", bundle: .module)
        }
    }

}
