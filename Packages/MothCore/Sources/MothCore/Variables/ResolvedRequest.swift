//  ResolvedRequest.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// Holds plaintext secrets, so it is not a ``Request``: nothing that persists a request can accept one.
public nonisolated struct ResolvedRequest: Sendable, Hashable {

    public var method: HTTPMethod
    public var url: String
    public var queryParameters: [KeyValue]
    public var pathParameters: [KeyValue]
    public var headers: [KeyValue]
    public var body: RequestBody
    /// Keeps its references, because OAuth2 writes refreshed tokens back through them.
    /// Its strings are expanded and can hold a secret, so never assign it to a ``Request``.
    public var auth: Auth
    public var credentials: [SecretReference: String]
    public var settings: RequestSettings
    public var unresolved: [UnresolvedVariable]
    public var unresolvedCredentials: [SecretReference]
    var unresolvedParts: [String: Set<RequestPart>] = [:]

    public init(
        method: HTTPMethod = .get,
        url: String,
        queryParameters: [KeyValue] = [],
        pathParameters: [KeyValue] = [],
        headers: [KeyValue] = [],
        body: RequestBody = .none,
        auth: Auth = .none,
        credentials: [SecretReference: String] = [:],
        settings: RequestSettings = RequestSettings(),
        unresolved: [UnresolvedVariable] = [],
        unresolvedCredentials: [SecretReference] = []
    ) {
        self.method = method
        self.url = url
        self.queryParameters = queryParameters
        self.pathParameters = pathParameters
        self.headers = headers
        self.body = body
        self.auth = auth
        self.credentials = credentials
        self.settings = settings
        self.unresolved = unresolved
        self.unresolvedCredentials = unresolvedCredentials
    }

    func unresolved(outside leftOut: Set<RequestPart>) -> [UnresolvedVariable] {
        unresolved.filter { variable in
            unresolvedParts[variable.name].map { !$0.isSubset(of: leftOut) } ?? true
        }
    }

}
