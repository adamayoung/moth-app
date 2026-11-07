//  RequestPart.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated enum RequestPart: Sendable, Hashable {

    case address
    case row(UUID)
    case body
    case auth

}
