//  VariableResolution+Request.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated extension VariableResolution {

    mutating func resolve(_ rows: [KeyValue]) async throws -> [KeyValue] {
        var resolved = rows

        for index in resolved.indices where resolved[index].isEnabled {
            resolved[index].key = try await resolve(key: resolved[index].key, ofRow: resolved[index].id)
            resolved[index].value = try await resolve(resolved[index].value)
        }

        return resolved
    }

    mutating func resolve(_ body: RequestBody) async throws -> RequestBody {
        part = .body

        switch body {
        case .none, .binary:
            return body
        case .formData(let fields):
            return try await .formData(resolve(fields))
        case .urlEncoded(let rows):
            return try await .urlEncoded(resolve(rows))
        case .raw(let content, let contentType):
            let content = try await resolve(content)
            return try await .raw(content: content, contentType: resolve(contentType))
        case .graphQL(let query, let variables):
            let query = try await resolve(query)
            return try await .graphQL(query: query, variables: resolve(variables))
        }
    }

    /// Stays an ``Auth``. `.inherit` passes through with no credentials, so a caller replaces it before resolving.
    mutating func resolve(_ auth: Auth) async throws -> Auth {
        part = .auth

        switch auth {
        case .inherit, .none:
            return auth
        case .basic(var basic):
            basic.username = try await resolve(basic.username)
            try await resolveCredentials(basic.password)
            return .basic(basic)
        case .bearer(let bearer):
            try await resolveCredentials(bearer.token)
            return .bearer(bearer)
        case .apiKey(var apiKey):
            apiKey.name = try await resolve(apiKey.name)
            try await resolveCredentials(apiKey.value)
            return .apiKey(apiKey)
        case .digest(var digest):
            digest.username = try await resolve(digest.username)
            try await resolveCredentials(digest.password)
            return .digest(digest)
        case .oauth2(let oauth2):
            return try await .oauth2(resolve(oauth2))
        case .awsSigV4(var sigV4):
            sigV4.region = try await resolve(sigV4.region)
            sigV4.service = try await resolve(sigV4.service)
            try await resolveCredentials(sigV4.accessKeyID, sigV4.secretAccessKey, sigV4.sessionToken)
            return .awsSigV4(sigV4)
        }
    }

    private mutating func resolve(_ fields: [FormDataField]) async throws -> [FormDataField] {
        var resolved = fields

        for index in resolved.indices where resolved[index].isEnabled {
            resolved[index] = try await resolve(resolved[index])
        }

        return resolved
    }

    private mutating func resolve(_ field: FormDataField) async throws -> FormDataField {
        var resolved = field
        resolved.key = try await resolve(key: field.key, ofRow: field.id)

        if let contentType = field.contentType {
            resolved.contentType = try await resolve(contentType)
        }

        if case .text(let text) = field.value {
            resolved.value = try await .text(resolve(text))
        }

        return resolved
    }

    private mutating func resolve(_ oauth2: OAuth2Auth) async throws -> OAuth2Auth {
        var resolved = oauth2
        resolved.authorizationURL = try await resolve(oauth2.authorizationURL)
        resolved.accessTokenURL = try await resolve(oauth2.accessTokenURL)
        resolved.callbackURL = try await resolve(oauth2.callbackURL)
        resolved.clientID = try await resolve(oauth2.clientID)
        resolved.scope = try await resolve(oauth2.scope)
        resolved.username = try await resolve(oauth2.username)
        try await resolveCredentials(oauth2.clientSecret, oauth2.password, oauth2.accessToken, oauth2.refreshToken)

        return resolved
    }

}
