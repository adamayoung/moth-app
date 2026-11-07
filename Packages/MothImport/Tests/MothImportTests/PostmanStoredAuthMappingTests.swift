//  PostmanStoredAuthMappingTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import MothImport
import Testing

struct PostmanStoredAuthMappingTests {

    @Test(
        "OAuth2's current key spellings map, from a snippet because the fixture has the older ones",
        arguments: [
            ("authorization_code", OAuth2GrantType.authorizationCode),
            ("authorization_code_with_pkce", .authorizationCodeWithPKCE),
            ("implicit", .implicit),
            ("password_credentials", .passwordCredentials),
            ("client_credentials", .clientCredentials)
        ]
    )
    func mapsOAuth2CurrentSpellings(grant: String, grantType: OAuth2GrantType) async throws {
        let result = try await Fixture.importingAuth(#"""
        {
            "type": "oauth2",
            "oauth2": [
                { "key": "grant_type", "value": "\#(grant)" },
                { "key": "redirect_uri", "value": "https://a.test/cb" }
            ]
        }
        """#)

        guard case .oauth2(let oauth2) = result.collection?.requests.first?.auth else {
            Issue.record("Expected OAuth2 auth")
            return
        }

        #expect(oauth2.grantType == grantType)
        #expect(oauth2.callbackURL == "https://a.test/cb")
    }

    @Test("An optional credential left empty has no reference")
    func emptyOptionalCredentialHasNoReference() async throws {
        let result = try await Fixture.importingAuth(#"""
        { "type": "oauth2", "oauth2": [{ "key": "clientSecret", "value": "" }] }
        """#)

        guard case .oauth2(let oauth2) = result.collection?.requests.first?.auth else {
            Issue.record("Expected OAuth2 auth")
            return
        }

        #expect(oauth2.clientSecret == nil)
        #expect(result.secrets.isEmpty)
    }

    @Test(
        "An API key maps its name, location and value, from a snippet because no licensed fixture has one",
        arguments: [("query", APIKeyLocation.query), ("header", .header)]
    )
    func mapsAPIKey(location: String, expected: APIKeyLocation) async throws {
        let store = InMemorySecretStore()
        let result = try await Fixture.importingSnippet(
            items: #"""
            [{
                "name": "a",
                "request": {
                    "auth": {
                        "type": "apikey",
                        "apikey": [
                            { "key": "key", "value": "X-Key" },
                            { "key": "value", "value": "abc" },
                            { "key": "in", "value": "\#(location)" }
                        ]
                    }
                }
            }]
            """#,
            secretStore: store
        )

        guard case .apiKey(let apiKey) = result.collection?.requests.first?.auth else {
            Issue.record("Expected an API key")
            return
        }

        #expect(apiKey.name == "X-Key")
        #expect(apiKey.location == expected)
        #expect(await Fixture.stored(apiKey.value, in: store) == "abc")
        #expect(result.imported.unsupportedAuth.isEmpty)
    }

    @Test("A real Postman export's API key goes out, replacing the header Postman wrote beside it")
    func appliesAnExportedAPIKey() async throws {
        let store = InMemorySecretStore()
        let exported = try #require(
            String(bytes: Fixture.data("postman-schemas/apikeyAuthTest.json"), encoding: .utf8)
        )
        // This export declares the `http` schema URL, which `PostmanSchema` doesn't accept.
        let accepted = exported.replacing("http://schema", with: "https://schema")
        let imported = try await Fixture.importing(contents: accepted, secretStore: store)
        let collection = try #require(imported.collection)
        let request = try #require(collection.requests.first)

        let built = try await Self.built(request, in: collection, store: store)

        #expect(imported.imported.unsupportedAuth.isEmpty)
        #expect(built.urlRequest.url?.absoluteString == "https://postman-echo.com/get")
        #expect(built.urlRequest.allHTTPHeaderFields == ["token": "wkjehbxoqnunc2k3"])
        #expect(built.notices.isEmpty)
    }

    @Test("An imported query key with variables goes out, from a snippet because no licensed fixture has one")
    func appliesAnImportedQueryKey() async throws {
        let store = InMemorySecretStore()
        let collection = try #require(await Fixture.importingSnippet(
            items: #"""
            [{
                "name": "a",
                "request": {
                    "method": "GET",
                    "url": "https://example.com/users",
                    "auth": {
                        "type": "apikey",
                        "apikey": [
                            { "key": "key", "value": "{{keyName}}", "type": "string" },
                            { "key": "value", "value": "{{keyValue}}", "type": "string" },
                            { "key": "in", "value": "query", "type": "string" }
                        ]
                    }
                }
            }]
            """#,
            extraKeys: #"""
            "variable": [
                { "key": "keyName", "value": "api_key" },
                { "key": "keyValue", "value": "a b" }
            ],
            """#,
            secretStore: store
        ).collection)
        let request = try #require(collection.requests.first)

        let built = try await Self.built(request, in: collection, store: store)

        #expect(built.urlRequest.url?.absoluteString == "https://example.com/users?api_key=a%20b")
        #expect(built.notices.isEmpty)
    }

    private static func built(
        _ request: Request,
        in collection: RequestCollection,
        store: some SecretStore
    ) async throws -> BuiltRequest {
        let resolved = try await VariableResolver(secretStore: store).resolve(
            request,
            collection: collection.variables,
            environment: [],
            globals: []
        )
        return try await RequestBuilder().build(resolved)
    }

    @Test("An API key with no location goes in a header, Postman's default")
    func apiKeyDefaultsToHeader() async throws {
        let result = try await Fixture
            .importingAuth(#"{ "type": "apikey", "apikey": [{ "key": "key", "value": "a" }] }"#)

        guard case .apiKey(let apiKey) = result.collection?.requests.first?.auth else {
            Issue.record("Expected an API key")
            return
        }

        #expect(apiKey.location == .header)
    }

    @Test("AWS maps each field, from a snippet because no licensed fixture has one")
    func mapsAWS() async throws {
        let store = InMemorySecretStore()
        let result = try await Fixture.importingSnippet(
            items: #"""
            [{
                "name": "a",
                "request": {
                    "auth": {
                        "type": "awsv4",
                        "awsv4": [
                            { "key": "accessKey", "value": "AK" },
                            { "key": "secretKey", "value": "SK" },
                            { "key": "sessionToken", "value": "ST" },
                            { "key": "region", "value": "eu-west-2" },
                            { "key": "service", "value": "s3" }
                        ]
                    }
                }
            }]
            """#,
            secretStore: store
        )

        guard case .awsSigV4(let sigV4) = result.collection?.requests.first?.auth else {
            Issue.record("Expected AWS auth")
            return
        }

        #expect(sigV4.region == "eu-west-2")
        #expect(sigV4.service == "s3")
        #expect(await Fixture.stored(sigV4.accessKeyID, in: store) == "AK")
        #expect(await Fixture.stored(sigV4.secretAccessKey, in: store) == "SK")
        #expect(await Fixture.stored(sigV4.sessionToken, in: store) == "ST")
        #expect(result.imported.unsupportedAuth[.awsSigV4] == 1)
    }

}
