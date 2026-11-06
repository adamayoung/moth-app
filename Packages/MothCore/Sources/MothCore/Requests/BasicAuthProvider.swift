//  BasicAuthProvider.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct BasicAuthProvider: AuthProvider {

    private let username: String
    private let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func apply(to request: inout URLRequest) async throws {
        let credentials = Data("\(username):\(password)".utf8).base64EncodedString()

        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
    }

}
