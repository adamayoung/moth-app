//  VariableResolver.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated struct VariableResolver: Sendable {

    private let secretStore: any SecretStore
    private let dynamicVariables: DynamicVariables

    public init(secretStore: any SecretStore, dynamicVariables: DynamicVariables = .live) {
        self.secretStore = secretStore
        self.dynamicVariables = dynamicVariables
    }

    @concurrent
    public func resolve(
        _ request: Request,
        collection: [Variable],
        environment: [Variable],
        globals: [Variable]
    ) async throws -> ResolvedRequest {
        var resolution = VariableResolution(
            scopes: [request.variables, collection, environment, globals],
            secretStore: secretStore,
            dynamicVariables: dynamicVariables
        )
        let url = try await resolution.resolve(request.urlTemplate)
        let queryParameters = try await resolution.resolve(request.queryParameters)
        let pathParameters = try await resolution.resolve(request.pathParameters)
        let headers = try await resolution.resolve(request.headers)
        let body = try await resolution.resolve(request.body)
        let auth = try await resolution.resolve(request.auth)

        var resolved = ResolvedRequest(
            method: request.method,
            url: url,
            queryParameters: queryParameters,
            pathParameters: pathParameters,
            headers: headers,
            body: body,
            auth: auth,
            credentials: resolution.credentials,
            settings: request.settings,
            unresolved: resolution.unresolved,
            unresolvedCredentials: resolution.unresolvedCredentials
        )
        resolved.unresolvedParts = resolution.unresolvedParts

        return resolved
    }

}
