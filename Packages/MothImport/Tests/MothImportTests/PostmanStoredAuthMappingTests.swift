//  PostmanStoredAuthMappingTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

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
        #expect(result.imported.unsupportedAuth[.apiKey] == 1)
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
