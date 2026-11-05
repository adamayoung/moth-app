//  VariableResolverFieldTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct VariableResolverFieldTests {

    private let resolver = VariableResolver(secretStore: InMemorySecretStore())

    @Test("The URL and every enabled row’s key and value resolve")
    func urlAndRowsResolve() async throws {
        let request = Request(
            name: "Request",
            urlTemplate: "https://{{v}}",
            queryParameters: [KeyValue(key: "query-{{v}}", value: "{{v}}")],
            pathParameters: [KeyValue(key: "path-{{v}}", value: "{{v}}")],
            headers: [KeyValue(key: "header-{{v}}", value: "{{v}}")]
        )

        let resolved = try await resolve(request)

        #expect(resolved.url == "https://x")
        #expect(pairs(resolved.queryParameters) == ["query-x: x"])
        #expect(pairs(resolved.pathParameters) == ["path-x: x"])
        #expect(pairs(resolved.headers) == ["header-x: x"])
        #expect(resolved.unresolved.isEmpty)
    }

    @Test("A resolved row keeps its identity")
    func rowsKeepTheirIdentity() async throws {
        let header = KeyValue(key: "{{v}}", value: "{{v}}")

        let resolved = try await resolve(Request(name: "Request", headers: [header]))

        #expect(resolved.headers.map(\.id) == [header.id])
    }

    @Test("The method and settings pass through")
    func methodAndSettingsPassThrough() async throws {
        let settings = RequestSettings(timeout: .seconds(5), followsRedirects: false, verifiesTLS: false)

        let resolved = try await resolve(Request(name: "Request", method: .post, settings: settings))

        #expect(resolved.method == .post)
        #expect(resolved.settings == settings)
    }

    @Test("A raw body resolves its content and content type")
    func rawBodyResolves() async throws {
        let resolved = try await resolve(body: .raw(content: "{{v}}", contentType: "text/{{v}}"))

        #expect(resolved.body == .raw(content: "x", contentType: "text/x"))
    }

    @Test("A GraphQL body resolves its query and variables")
    func graphQLBodyResolves() async throws {
        let resolved = try await resolve(body: .graphQL(query: "{{v}}", variables: "{{v}}"))

        #expect(resolved.body == .graphQL(query: "x", variables: "x"))
    }

    @Test("A URL-encoded body resolves its keys and values")
    func urlEncodedBodyResolves() async throws {
        let row = KeyValue(key: "key-{{v}}", value: "{{v}}")

        let resolved = try await resolve(body: .urlEncoded([row]))

        #expect(resolved.body == .urlEncoded([KeyValue(id: row.id, key: "key-x", value: "x")]))
    }

    @Test("A form-data text field resolves its key, value and content type")
    func formDataTextResolves() async throws {
        let field = FormDataField(key: "key-{{v}}", value: .text("{{v}}"), contentType: "text/{{v}}")

        let resolved = try await resolve(body: .formData([field]))

        let expected = FormDataField(id: field.id, key: "key-x", value: .text("x"), contentType: "text/x")
        #expect(resolved.body == .formData([expected]))
    }

    @Test("A form-data file field resolves its key and leaves its paths")
    func formDataFileKeepsItsPaths() async throws {
        let field = FormDataField(key: "key-{{v}}", value: .file(paths: ["{{missing}}/a.txt"]))

        let resolved = try await resolve(body: .formData([field]))

        let expected = FormDataField(id: field.id, key: "key-x", value: .file(paths: ["{{missing}}/a.txt"]))
        #expect(resolved.body == .formData([expected]))
        #expect(resolved.unresolved.isEmpty)
    }

    @Test("A binary body leaves its path")
    func binaryBodyKeepsItsPath() async throws {
        let resolved = try await resolve(body: .binary(filePath: "{{missing}}/a.bin"))

        #expect(resolved.body == .binary(filePath: "{{missing}}/a.bin"))
        #expect(resolved.unresolved.isEmpty)
    }

    @Test("Disabled rows stay as written and are not reported")
    func disabledRowsAreIgnored() async throws {
        let row = KeyValue(key: "{{missing}}", value: "{{missing}}", isEnabled: false)
        let field = FormDataField(key: "{{missing}}", value: .text("{{missing}}"), isEnabled: false)
        let request = Request(
            name: "Request",
            queryParameters: [row],
            pathParameters: [row],
            headers: [row],
            body: .urlEncoded([row])
        )

        let resolved = try await resolve(request)
        let formResolved = try await resolve(body: .formData([field]))

        #expect(resolved.queryParameters == [row])
        #expect(resolved.pathParameters == [row])
        #expect(resolved.headers == [row])
        #expect(resolved.body == .urlEncoded([row]))
        #expect(formResolved.body == .formData([field]))
        #expect(resolved.unresolved.isEmpty)
        #expect(formResolved.unresolved.isEmpty)
    }

    @Test("Basic and Digest usernames resolve")
    func usernamesResolve() async throws {
        let password = SecretReference()

        let basic = try await resolve(auth: .basic(BasicAuth(username: "{{v}}", password: password)))
        let digest = try await resolve(auth: .digest(DigestAuth(username: "{{v}}", password: password)))

        #expect(basic.auth == .basic(BasicAuth(username: "x", password: password)))
        #expect(digest.auth == .digest(DigestAuth(username: "x", password: password)))
    }

    @Test("An API key’s name resolves")
    func apiKeyNameResolves() async throws {
        let value = SecretReference()

        let resolved = try await resolve(auth: .apiKey(APIKeyAuth(name: "{{v}}", value: value, location: .query)))

        #expect(resolved.auth == .apiKey(APIKeyAuth(name: "x", value: value, location: .query)))
    }

    @Test("Every OAuth2 string resolves")
    func oauth2StringsResolve() async throws {
        let resolved = try await resolve(auth: .oauth2(oauth2(allStringsAre: "{{v}}")))

        #expect(resolved.auth == .oauth2(oauth2(allStringsAre: "x")))
    }

    @Test("SigV4’s region and service resolve")
    func sigV4StringsResolve() async throws {
        let key = SecretReference()
        let auth = AWSSigV4Auth(accessKeyID: key, secretAccessKey: key, region: "{{v}}", service: "{{v}}")

        let resolved = try await resolve(auth: .awsSigV4(auth))

        #expect(resolved.auth == .awsSigV4(AWSSigV4Auth(
            accessKeyID: key,
            secretAccessKey: key,
            region: "x",
            service: "x"
        )))
    }

    @Test("Auth with nothing to resolve passes through", arguments: [Auth.inherit, Auth.none])
    func authWithoutFieldsPassesThrough(auth: Auth) async throws {
        let resolved = try await resolve(auth: auth)

        #expect(resolved.auth == auth)
    }

    private func resolve(_ request: Request) async throws -> ResolvedRequest {
        try await resolver.resolve(request, collection: [], environment: [.plain("v", "x")], globals: [])
    }

    private func resolve(body: RequestBody) async throws -> ResolvedRequest {
        try await resolve(Request(name: "Request", body: body))
    }

    private func resolve(auth: Auth) async throws -> ResolvedRequest {
        try await resolve(Request(name: "Request", auth: auth))
    }

    private func pairs(_ rows: [KeyValue]) -> [String] {
        rows.map { "\($0.key): \($0.value)" }
    }

    private func oauth2(allStringsAre value: String) -> OAuth2Auth {
        OAuth2Auth(
            grantType: .clientCredentials,
            authorizationURL: value,
            accessTokenURL: value,
            callbackURL: value,
            clientID: value,
            scope: value,
            username: value
        )
    }

}
