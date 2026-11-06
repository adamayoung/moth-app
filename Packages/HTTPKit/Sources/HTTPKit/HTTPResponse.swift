//  HTTPResponse.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public struct HTTPResponse: Equatable, Sendable {

    public let status: Int
    public let headers: [String: String]
    public let body: Data
    /// URLSession doesn't promise metrics before a send returns, and a stub transport has none.
    public let metrics: HTTPMetrics?

    public init(status: Int, headers: [String: String], body: Data, metrics: HTTPMetrics? = nil) {
        self.status = status
        self.headers = headers
        self.body = body
        self.metrics = metrics
    }

    public func value(forHeader name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

}
