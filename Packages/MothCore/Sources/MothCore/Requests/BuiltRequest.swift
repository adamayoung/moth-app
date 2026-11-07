//  BuiltRequest.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// `urlRequest` can hold plaintext secrets in its headers, so never log or persist one.
public nonisolated struct BuiltRequest: Sendable, Hashable {

    public var urlRequest: URLRequest
    public var notices: [RequestBuildNotice]
    public var unresolved: [UnresolvedVariable]

    public init(
        urlRequest: URLRequest,
        notices: [RequestBuildNotice] = [],
        unresolved: [UnresolvedVariable] = []
    ) {
        self.urlRequest = urlRequest
        self.notices = notices
        self.unresolved = unresolved
    }

}
