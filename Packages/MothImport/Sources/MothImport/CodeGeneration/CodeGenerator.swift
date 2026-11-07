//  CodeGenerator.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore

/// Takes no `SecretStore`, so what it generates can't hold a secret: a secret variable stays `{{name}}`, and a
/// credential is only ever a placeholder.
public nonisolated struct CodeGenerator: Sendable {

    private let dynamicVariables: DynamicVariables

    public init(dynamicVariables: DynamicVariables = .live) {
        self.dynamicVariables = dynamicVariables
    }

    /// `request` needs its effective auth, because `.inherit` generates no auth.
    @concurrent
    public func code(for request: Request, scopes: VariableScopes) async throws -> GeneratedCode {
        let resolved = try await VariableResolver(secretStore: NoSecrets(), dynamicVariables: dynamicVariables).resolve(
            request,
            collection: scopes.collection,
            environment: scopes.environment,
            globals: scopes.globals
        )
        let written = CodeRequest(resolved)
        return GeneratedCode(curl: written.curl, swift: written.urlSession)
    }

}

private nonisolated struct NoSecrets: SecretStore {

    func save(_ value: String, for identifier: String) async throws {}

    func value(for identifier: String) async throws -> String? {
        nil
    }

    func removeValue(for identifier: String) async throws {}

}
