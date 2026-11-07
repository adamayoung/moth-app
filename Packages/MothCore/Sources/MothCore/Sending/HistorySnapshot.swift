//  HistorySnapshot.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// Resolves with a store that answers nothing, so a secret variable stays `{{name}}` and no credential is read.
nonisolated enum HistorySnapshot {

    /// Keeps every variable in scope, so a secret's own value can still name the others on Send Again.
    static func make(
        of request: Request,
        scopes: VariableScopes,
        replaying values: DynamicValueLog
    ) async throws -> Request {
        let resolved = try await VariableResolver(secretStore: NoSecrets(), dynamicVariables: values.replaying)
            .resolve(request, collection: scopes.collection, environment: scopes.environment, globals: scopes.globals)
        let scopesInOrder = [request.variables, scopes.collection, scopes.environment, scopes.globals]

        var snapshot = request
        snapshot.urlTemplate = resolved.url
        snapshot.pathParameters = resolved.pathParameters
        snapshot.headers = masked(resolved.headers, replacedBy: resolved)
        snapshot.body = resolved.body
        snapshot.auth = resolved.auth
        snapshot.queryParameters = resolved.queryParameters.map { row in
            resolved.rowsReplacedByAuth.contains(.row(row.id)) ? row.masked : row
        }
        snapshot.variables = variablesInScope(scopesInOrder)
        return snapshot
    }

    /// A masked row is lost unless an auth provider replaces it, as one with no credential, or Digest, doesn't.
    static func hasLostRow(in resolved: ResolvedRequest) -> Bool {
        let hasProvider = resolved.getsAccessTokenAtSend || resolved.authProvider(signingAt: .distantPast) != nil
        let replaced = hasProvider ? resolved.rowsReplacedByAuth : []
        return (resolved.headers + resolved.queryParameters).contains { row in
            row.isEnabled && row.value == HistoryEntry.maskedValue && !replaced.contains(.row(row.id))
        }
    }

    private static func masked(_ headers: [KeyValue], replacedBy resolved: ResolvedRequest) -> [KeyValue] {
        let replaced = resolved.rowsReplacedByAuth
        return headers.map { row in
            let carriesCredentials = ["authorization", "proxy-authorization"].contains(row.key.lowercased())
            return carriesCredentials || replaced.contains(.row(row.id)) ? row.masked : row
        }
    }

    private static func variablesInScope(_ scopesInOrder: [[Variable]]) -> [Variable] {
        var names: Set<String> = []
        return scopesInOrder.flatMap { $0.reversed() }.filter { variable in
            variable.isEnabled && names.insert(variable.name).inserted
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
