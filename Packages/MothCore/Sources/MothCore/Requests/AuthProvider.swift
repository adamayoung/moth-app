//  AuthProvider.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated protocol AuthProvider: Sendable {

    /// `async throws` for what comes next: OAuth2 refreshes tokens, and SigV4 signs the final body.
    func apply(to request: inout URLRequest) async throws

    /// The headers `apply` sets that hold a secret, which a redirect to another origin leaves behind. No default, so a
    /// new provider can't leak one by forgetting.
    var credentialHeaders: Set<String> { get }

}
