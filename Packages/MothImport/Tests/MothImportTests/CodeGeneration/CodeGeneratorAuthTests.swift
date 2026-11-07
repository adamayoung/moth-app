//  CodeGeneratorAuthTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct CodeGeneratorAuthTests {

    private func code(auth: Auth, headers: [KeyValue] = []) async throws -> GeneratedCode {
        try await CodeGenerator().code(
            for: Request(name: "Users", urlTemplate: "https://example.com/users", headers: headers, auth: auth),
            scopes: VariableScopes()
        )
    }

    private nonisolated static let digest = Auth.digest(DigestAuth(username: "alice", password: SecretReference()))
    private nonisolated static let oauth2 = Auth.oauth2(OAuth2Auth(
        grantType: .clientCredentials,
        authorizationURL: "",
        accessTokenURL: "",
        callbackURL: "",
        clientID: "client",
        scope: ""
    ))
    private nonisolated static let awsSigV4 = Auth.awsSigV4(AWSSigV4Auth(
        accessKeyID: SecretReference(),
        secretAccessKey: SecretReference(),
        region: "eu-west-1",
        service: "s3"
    ))

    @Test("Basic is complete but for its password")
    func basic() async throws {
        let code = try await code(auth: .basic(BasicAuth(username: "alice", password: SecretReference())))

        #expect(code.curl.contains("--user 'alice:<password>'"))
        #expect(code.swift.contains(#"let credentials = Data("alice:<password>".utf8).base64EncodedString()"#))
        #expect(code.swift.contains(#"request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")"#))
    }

    @Test("Bearer is complete but for its token")
    func bearer() async throws {
        let code = try await code(auth: .bearer(BearerAuth(token: SecretReference())))

        #expect(code.curl.contains("--header 'Authorization: Bearer <token>'"))
        #expect(code.swift.contains(#"request.addValue("Bearer <token>", forHTTPHeaderField: "Authorization")"#))
    }

    @Test("An API key in a header is complete but for its value")
    func apiKeyInHeader() async throws {
        let code = try await code(auth: .apiKey(APIKeyAuth(name: "X-Key", value: SecretReference(), location: .header)))

        #expect(code.curl.contains("--header 'X-Key: <api-key>'"))
        #expect(code.swift.contains(#"request.addValue("<api-key>", forHTTPHeaderField: "X-Key")"#))
    }

    @Test("An API key in the query is complete but for its value, which stays readable")
    func apiKeyInQuery() async throws {
        let code = try await code(auth: .apiKey(APIKeyAuth(
            name: "api key",
            value: SecretReference(),
            location: .query
        )))

        #expect(code.curl.contains("'https://example.com/users?api%20key=<api-key>'"))
        #expect(code.swift.contains(#"URL(string: "https://example.com/users?api%20key=<api-key>")!"#))
    }

    @Test("An API key in the query replaces a manual row and a pair in the URL of its name, as it does on Send")
    func apiKeyInQueryReplaces() async throws {
        let code = try await CodeGenerator().code(
            for: Request(
                name: "Users",
                urlTemplate: "https://example.com?key=typed&a=1",
                queryParameters: [KeyValue(key: "key", value: "row")],
                auth: .apiKey(APIKeyAuth(name: "key", value: SecretReference(), location: .query))
            ),
            scopes: VariableScopes()
        )

        #expect(code.curl == "curl --url 'https://example.com?a=1&key=<api-key>'")
    }

    @Test("An API key name Send refuses is left out, with a comment", arguments: ["@/etc/passwd", "X\r\nEvil: 1"])
    func apiKeyWithAnUnsendableName(name: String) async throws {
        let code = try await code(auth: .apiKey(APIKeyAuth(name: name, value: SecretReference(), location: .header)))

        let comment = "Headers that can\u{2019}t be sent are left out."
        #expect(code.curl == "# \(comment)\ncurl --url 'https://example.com/users'")
    }

    @Test("An API key with no name sends nothing, and says so, as it does on Send")
    func apiKeyWithNoName() async throws {
        let code = try await code(auth: .apiKey(APIKeyAuth(name: "", value: SecretReference(), location: .header)))

        let comment = "The API key is left out, because it has no name."
        #expect(code.curl == "# \(comment)\ncurl --url 'https://example.com/users'")
        #expect(code.swift.hasPrefix("// \(comment)\nimport Foundation"))
    }

    @Test("A manual row gives way to the auth that sets the same header, as it does on Send")
    func manualRowGivesWay() async throws {
        let headers = [
            KeyValue(key: "authorization", value: "manual"),
            KeyValue(key: "x-key", value: "manual"),
            KeyValue(key: "Accept", value: "*/*")
        ]

        let bearer = try await code(auth: .bearer(BearerAuth(token: SecretReference())), headers: headers)
        let basic = try await code(
            auth: .basic(BasicAuth(username: "alice", password: SecretReference())),
            headers: headers
        )
        let apiKey = try await code(
            auth: .apiKey(APIKeyAuth(name: "X-Key", value: SecretReference(), location: .header)),
            headers: headers
        )

        #expect(!bearer.curl.contains("authorization: manual"))
        #expect(!basic.curl.contains("authorization: manual"))
        #expect(!apiKey.curl.contains("x-key: manual"))
        #expect(bearer.curl.contains("Accept"))
        #expect(bearer.curl.contains("x-key: manual"))
    }

    @Test(
        "An auth Moth doesn't generate gives a comment in both languages, and nothing else",
        arguments: [
            (digest, "Digest auth is left out of this code."),
            (oauth2, "OAuth 2.0 is left out of this code."),
            (awsSigV4, "AWS Signature auth is left out of this code.")
        ]
    )
    func leftOutAuth(auth: Auth, comment: String) async throws {
        let code = try await code(auth: auth)

        #expect(code.curl == "# \(comment)\ncurl --url 'https://example.com/users'")
        #expect(code.swift.hasPrefix("// \(comment)\nimport Foundation"))
        #expect(!code.swift.contains("Authorization"))
    }

    @Test(
        "No auth, and auth nothing replaced, generate none",
        arguments: [Auth.none, .inherit]
    )
    func noAuth(auth: Auth) async throws {
        let code = try await code(auth: auth)

        #expect(code.curl == "curl --url 'https://example.com/users'")
    }

    @Test("Variables in a username and key name resolve, and a secret one stays as written")
    func variablesInAuthFields() async throws {
        let request = Request(
            name: "Users",
            urlTemplate: "https://example.com",
            auth: .basic(BasicAuth(username: "{{user}}-{{hidden}}", password: SecretReference()))
        )

        let code = try await CodeGenerator().code(
            for: request,
            scopes: VariableScopes(environment: [
                Variable(name: "user", value: .plain(initial: "", current: "alice")),
                Variable(name: "hidden", value: .secret(SecretReference()))
            ])
        )

        #expect(code.curl.contains("--user 'alice-{{hidden}}:<password>'"))
    }

}
