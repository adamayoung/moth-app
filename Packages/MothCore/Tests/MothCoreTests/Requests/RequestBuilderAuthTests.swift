//  RequestBuilderAuthTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct RequestBuilderAuthTests {

    private let builder = RequestBuilder()
    private let secret = SecretReference(identifier: "secret")

    @Test(
        "Basic auth sends RFC 7617's encoding",
        arguments: [
            ("Aladdin", "open sesame", "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ=="),
            ("test", "123£", "Basic dGVzdDoxMjPCow==")
        ]
    )
    func basic(username: String, password: String, expected: String) async throws {
        let built = try await build(
            auth: .basic(BasicAuth(username: username, password: secret)),
            credentials: [secret: password]
        )

        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == expected)
    }

    @Test("Bearer auth sends its token")
    func bearer() async throws {
        let built = try await build(auth: .bearer(BearerAuth(token: secret)), credentials: [secret: "abc"])

        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
    }

    @Test("Auth replaces a manual header, in any case", arguments: ["Authorization", "authorization"])
    func authReplacesManualHeader(name: String) async throws {
        let built = try await build(
            auth: .bearer(BearerAuth(token: secret)),
            credentials: [secret: "abc"],
            headers: [KeyValue(key: name, value: "Bearer manual")]
        )

        #expect(built.urlRequest.allHTTPHeaderFields?.count == 1)
        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
    }

    @Test(
        "An unsupported auth kind sends no auth and is reported",
        arguments: [
            (
                Auth.apiKey(
                    APIKeyAuth(name: "key", value: SecretReference(identifier: "secret"), location: .header)
                ),
                UnsupportedAuthKind.apiKey
            ),
            (.digest(DigestAuth(username: "user", password: SecretReference(identifier: "secret"))), .digest),
            (.oauth2(RequestBuilderAuthTests.oauth2), .oauth2),
            (.awsSigV4(RequestBuilderAuthTests.sigV4), .awsSigV4)
        ]
    )
    func unsupportedAuth(auth: Auth, kind: UnsupportedAuthKind) async throws {
        let built = try await build(auth: auth, credentials: [secret: "abc"])

        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(built.notices == [.unsupportedAuth(kind)])
    }

    @Test(
        "No auth, and an Inherit with nothing to inherit, leave a manual header alone",
        arguments: [Auth.none, .inherit]
    )
    func noAuth(auth: Auth) async throws {
        let built = try await build(auth: auth, headers: [KeyValue(key: "Authorization", value: "Bearer manual")])

        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer manual")
        #expect(built.notices.isEmpty)
    }

    @Test(
        "A credential with no value sends no auth, because the resolver has reported it",
        arguments: [
            Auth.basic(BasicAuth(username: "user", password: SecretReference(identifier: "secret"))),
            .bearer(BearerAuth(token: SecretReference(identifier: "secret")))
        ]
    )
    func missingCredential(auth: Auth) async throws {
        let built = try await build(auth: auth)

        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(built.notices.isEmpty)
    }

    private func build(
        auth: Auth,
        credentials: [SecretReference: String] = [:],
        headers: [KeyValue] = []
    ) async throws -> BuiltRequest {
        try await builder.build(
            ResolvedRequest(url: "https://example.com", headers: headers, auth: auth, credentials: credentials)
        )
    }

    private nonisolated static var oauth2: OAuth2Auth {
        let reference = SecretReference(identifier: "secret")

        return OAuth2Auth(
            grantType: .clientCredentials,
            authorizationURL: "",
            accessTokenURL: "",
            callbackURL: "",
            clientID: "",
            clientSecret: reference,
            scope: "",
            username: "",
            password: reference,
            accessToken: reference,
            refreshToken: reference
        )
    }

    private nonisolated static var sigV4: AWSSigV4Auth {
        let reference = SecretReference(identifier: "secret")

        return AWSSigV4Auth(
            accessKeyID: reference,
            secretAccessKey: reference,
            sessionToken: reference,
            region: "",
            service: ""
        )
    }

}
