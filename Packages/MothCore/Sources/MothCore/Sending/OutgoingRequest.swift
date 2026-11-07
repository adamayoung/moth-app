//  OutgoingRequest.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// `typedCredentials` are plaintext, so never log or persist one.
public nonisolated struct OutgoingRequest: Sendable {

    public var request: Request
    public var typedCredentials: [CredentialWrite]

    public init(request: Request, typedCredentials: [CredentialWrite] = []) {
        self.request = request
        self.typedCredentials = typedCredentials
    }

}

public nonisolated extension RequestDraft {

    var hasURL: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `stored` supplies what the editor doesn't hold. `.inherit` is replaced here, because the resolver fetches
    /// secrets only for the auth it is given.
    func outgoing(from stored: Request, in tree: CollectionTree) throws -> OutgoingRequest {
        let edit = edit
        var request = stored
        request.method = edit.method
        request.urlTemplate = edit.urlTemplate
        request.queryParameters = edit.queryParameters
        request.pathParameters = edit.pathParameters
        request.headers = edit.headers
        request.body = edit.body
        request.settings = edit.settings
        request.auth = edit.auth == .inherit ? try tree.effectiveAuth(of: .request(stored.id)) : edit.auth
        return OutgoingRequest(request: request, typedCredentials: auth.credentialWrites())
    }

}
