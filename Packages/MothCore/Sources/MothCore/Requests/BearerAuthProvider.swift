//  BearerAuthProvider.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct BearerAuthProvider: AuthProvider {

    private let token: String

    public init(token: String) {
        self.token = token
    }

    public func apply(to request: inout URLRequest) async throws {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

}
