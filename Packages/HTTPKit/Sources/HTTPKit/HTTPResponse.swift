//  HTTPResponse.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public struct HTTPResponse: Equatable, Sendable {

    public let status: Int
    public let headers: [String: String]
    public let body: Data

    public init(status: Int, headers: [String: String], body: Data) {
        self.status = status
        self.headers = headers
        self.body = body
    }

}
