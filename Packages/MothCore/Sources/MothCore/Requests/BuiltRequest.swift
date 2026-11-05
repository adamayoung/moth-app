//  BuiltRequest.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct BuiltRequest: Sendable, Hashable {

    public var urlRequest: URLRequest

    public init(urlRequest: URLRequest) {
        self.urlRequest = urlRequest
    }

}
