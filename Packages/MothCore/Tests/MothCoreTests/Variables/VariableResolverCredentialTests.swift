//  VariableResolverCredentialTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct VariableResolverCredentialTests {

    private let store = InMemorySecretStore()
    private let token = SecretReference(identifier: "token")

    @Test("A credential resolves through the store and auth keeps its reference")
    func credentialResolves() async throws {
        await store.save("abc", for: "token")

        let resolved = try await resolve(auth: .bearer(BearerAuth(token: token)))

        #expect(resolved.credentials == [token: "abc"])
        #expect(resolved.auth == .bearer(BearerAuth(token: token)))
        #expect(resolved.unresolvedCredentials.isEmpty)
    }

    @Test("A credential stored as a reference resolves, as an imported one is")
    func credentialValueNests() async throws {
        await store.save("{{bearerToken}}", for: "token")

        let resolved = try await resolve(
            auth: .bearer(BearerAuth(token: token)),
            environment: [.plain("bearerToken", "abc")]
        )

        #expect(resolved.credentials == [token: "abc"])
    }

    @Test("An undefined name inside a credential stays as written and is reported")
    func undefinedNameInACredentialIsReported() async throws {
        await store.save("{{bearerToken}}", for: "token")

        let resolved = try await resolve(auth: .bearer(BearerAuth(token: token)))

        #expect(resolved.credentials == [token: "{{bearerToken}}"])
        #expect(resolved.unresolved == [UnresolvedVariable(name: "bearerToken", reason: .undefined)])
    }

    @Test("An API key's name and value resolve, and go out resolved", arguments: [
        (APIKeyLocation.header, "https://example.com", "abc" as String?),
        (.query, "https://example.com?X-Tenant=abc", nil)
    ])
    func apiKeyResolves(location: APIKeyLocation, url: String, header: String?) async throws {
        await store.save("{{keyValue}}", for: "token")

        let resolved = try await resolve(
            auth: .apiKey(APIKeyAuth(name: "X-{{keyName}}", value: token, location: location)),
            environment: [.plain("keyName", "Tenant"), .plain("keyValue", "abc")]
        )
        let built = try await RequestBuilder().build(ResolvedRequest(
            url: "https://example.com",
            auth: resolved.auth,
            credentials: resolved.credentials
        ))

        #expect(resolved.auth == .apiKey(APIKeyAuth(name: "X-Tenant", value: token, location: location)))
        #expect(resolved.credentials == [token: "abc"])
        #expect(built.urlRequest.url?.absoluteString == url)
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Tenant") == header)
    }

    @Test("A missing credential is reported by its reference, and has no value")
    func missingCredentialIsReported() async throws {
        let resolved = try await resolve(auth: .bearer(BearerAuth(token: token)))

        #expect(resolved.credentials.isEmpty)
        #expect(resolved.unresolvedCredentials == [token])
        #expect(resolved.unresolved.isEmpty)
    }

    @Test("A secret store failure on a credential is thrown")
    func storeFailureIsThrown() async {
        let resolver = VariableResolver(secretStore: FailingSecretStore())
        let request = Request(name: "Request", auth: .bearer(BearerAuth(token: token)))

        await #expect(throws: FailingSecretStore.Failure.self) {
            try await resolver.resolve(request, collection: [], environment: [], globals: [])
        }
    }

    @Test("Every credential of every auth kind resolves")
    func everyCredentialResolves() async throws {
        let first = SecretReference(identifier: "first")
        let second = SecretReference(identifier: "second")
        let third = SecretReference(identifier: "third")
        let fourth = SecretReference(identifier: "fourth")
        await store.save("1", for: "first")
        await store.save("2", for: "second")
        await store.save("3", for: "third")
        await store.save("4", for: "fourth")
        let oauth2 = OAuth2Auth(
            grantType: .passwordCredentials,
            authorizationURL: "",
            accessTokenURL: "",
            callbackURL: "",
            clientID: "",
            clientSecret: first,
            scope: "",
            password: second,
            accessToken: third,
            refreshToken: fourth
        )
        let sigV4 = AWSSigV4Auth(
            accessKeyID: first,
            secretAccessKey: second,
            sessionToken: third,
            region: "",
            service: ""
        )

        let resolvedOAuth2 = try await resolve(auth: .oauth2(oauth2))
        let resolvedSigV4 = try await resolve(auth: .awsSigV4(sigV4))
        let basic = try await resolve(auth: .basic(BasicAuth(username: "", password: first)))
        let digest = try await resolve(auth: .digest(DigestAuth(username: "", password: first)))
        let apiKey = try await resolve(auth: .apiKey(APIKeyAuth(name: "", value: first, location: .header)))

        #expect(resolvedOAuth2.credentials == [first: "1", second: "2", third: "3", fourth: "4"])
        #expect(resolvedSigV4.credentials == [first: "1", second: "2", third: "3"])
        #expect(basic.credentials == [first: "1"])
        #expect(digest.credentials == [first: "1"])
        #expect(apiKey.credentials == [first: "1"])
    }

    @Test("A credential a kind leaves out is not reported")
    func absentCredentialIsNotReported() async throws {
        let oauth2 = OAuth2Auth(
            grantType: .implicit,
            authorizationURL: "",
            accessTokenURL: "",
            callbackURL: "",
            clientID: "",
            scope: ""
        )

        let resolved = try await resolve(auth: .oauth2(oauth2))

        #expect(resolved.unresolvedCredentials.isEmpty)
    }

    private func resolve(auth: Auth, environment: [Variable] = []) async throws -> ResolvedRequest {
        try await VariableResolver(secretStore: store).resolve(
            Request(name: "Request", auth: auth),
            collection: [],
            environment: environment,
            globals: []
        )
    }

}
