//  SendCommand.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore

/// What Request > Send does for the current tab, which reads Cancel while its request is in flight.
enum SendCommand: Equatable {

    case send(Request.ID)
    case cancel(Request.ID)
    case unavailable

}
