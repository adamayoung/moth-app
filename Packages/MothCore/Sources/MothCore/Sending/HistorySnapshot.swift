//  HistorySnapshot.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// Resolves with a store that answers nothing, so a secret variable stays `{{name}}` and no credential is read.
nonisolated enum HistorySnapshot {

    static func make(
        of request: Request,
        scopes: VariableScopes,
        replaying values: DynamicValueLog
    ) async throws -> Request {
        let resolved = try await VariableResolver(secretStore: NoSecrets(), dynamicVariables: values.replaying)
            .resolve(request, collection: scopes.collection, environment: scopes.environment, globals: scopes.globals)
        let secretNames = resolved.unresolved.filter { $0.reason == .missingSecret }.map(\.name)
        let allScopes = [request.variables, scopes.collection, scopes.environment, scopes.globals]

        var snapshot = request
        snapshot.urlTemplate = resolved.url
        snapshot.queryParameters = resolved.queryParameters
        snapshot.pathParameters = resolved.pathParameters
        snapshot.headers = resolved.headers
        snapshot.body = resolved.body
        snapshot.auth = resolved.auth
        snapshot.variables = secretNames.compactMap { name in
            allScopes.lazy.compactMap { scope in scope.last { $0.isEnabled && $0.name == name } }.first
        }
        return masked(snapshot)
    }

    /// A masked row that the auth replaces is sent as the auth sets it, so only one it doesn't replace is lost.
    static func hasLostRow(_ request: Request) -> Bool {
        let replaced = replacedRows(by: request.auth)
        let lostHeader = request.headers.contains { row in
            row.isEnabled && row.value == HistoryEntry.maskedValue && !replaced.headers.contains(row.key.lowercased())
        }
        let lostQuery = request.queryParameters.contains { row in
            row.isEnabled && row.value == HistoryEntry.maskedValue && row.key != replaced.query
        }
        return lostHeader || lostQuery
    }

    static func masked(_ request: Request) -> Request {
        let replaced = replacedRows(by: request.auth)
        let maskedHeaders = replaced.headers.union(["authorization", "proxy-authorization"])
        var masked = request
        masked.headers = request.headers.map { row in
            maskedHeaders.contains(row.key.lowercased()) ? row.masked : row
        }
        masked.queryParameters = request.queryParameters.map { row in
            row.key == replaced.query ? row.masked : row
        }
        return masked
    }

    private static func replacedRows(by auth: Auth) -> (headers: Set<String>, query: String?) {
        switch auth {
        case .basic, .bearer, .digest, .awsSigV4:
            (["authorization"], nil)
        case .apiKey(let key) where key.location == .header:
            ([key.name.lowercased()], nil)
        case .apiKey(let key):
            ([], key.name)
        case .inherit, .none, .oauth2:
            ([], nil)
        }
    }

}

private nonisolated extension KeyValue {

    var masked: KeyValue {
        var row = self
        row.value = HistoryEntry.maskedValue
        return row
    }

}

private nonisolated struct NoSecrets: SecretStore {

    func save(_: String, for _: String) async throws {}

    func value(for _: String) async throws -> String? {
        nil
    }

    func removeValue(for _: String) async throws {}

}
