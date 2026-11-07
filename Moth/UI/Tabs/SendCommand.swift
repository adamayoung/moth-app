//  SendCommand.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore

enum SendCommand: Equatable {

    case send(Request.ID)
    case cancel(Request.ID)
    case unavailable

    var sendableRequest: Request.ID? {
        if case .send(let id) = self {
            id
        } else {
            nil
        }
    }

}
