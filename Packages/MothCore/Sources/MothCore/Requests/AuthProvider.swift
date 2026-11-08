//  AuthProvider.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated protocol AuthProvider: Sendable {

    /// `async throws` for what comes next: OAuth2 refreshes tokens, and SigV4 signs the final body.
    func apply(to request: inout URLRequest) async throws

    /// The headers `apply` adds that carry a secret, beyond `Authorization`, which a redirect to another origin drops.
    var credentialHeaders: Set<String> { get }

}

public nonisolated extension AuthProvider {

    var credentialHeaders: Set<String> {
        []
    }

}
