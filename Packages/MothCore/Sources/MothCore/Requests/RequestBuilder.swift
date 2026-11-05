//  RequestBuilder.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct RequestBuilder: Sendable {

    public init() {}

    @concurrent
    public func build(_ request: ResolvedRequest) async throws -> BuiltRequest {
        try BuiltRequest(urlRequest: URLRequest(url: request.sendableURL()))
    }

}
