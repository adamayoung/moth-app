//  PostmanAuthMappingTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct PostmanAuthMappingTests {

    private static let helpers = "postman-collection-transformer/v2.1.0/helpers.json"

    private static func stored(_ reference: SecretReference?, in store: InMemorySecretStore) async -> String? {
        guard let reference else {
            return nil
        }
        return await store.value(for: reference.identifier)
    }

    private static func requestAuth(_ auth: String) async throws -> PostmanImportResult {
        try await Fixture.importingSnippet(items: #"[{ "name": "a", "request": { "auth": \#(auth) } }]"#)
    }

    @Test("A request with no auth entry inherits")
    func unsetRequestInherits() async throws {
        let collection = try await Fixture.collection("postman-code-generators/basicCollection.json")

        #expect(collection.requests.allSatisfy { $0.auth == .inherit })
    }

    @Test("A request whose auth is null inherits, as Postman's own loader treats it")
    func nullRequestAuthInherits() async throws {
        let collection = try await Fixture.collection("openapi-to-postman/internalRefsCollection.json")

        #expect(try collection.request(named: "searches inventory").auth == .inherit)
    }

    @Test("A folder with no auth entry inherits, and a collection with none has No Auth")
    func unsetFolderInheritsAndCollectionHasNone() async throws {
        let collection = try await Fixture.collection("openapi-to-postman/collection.json")

        #expect(collection.children.first?.folder?.auth == .inherit)
        #expect(collection.auth == .none)
    }

    @Test("noauth is No Auth at each level, from a snippet because no licensed fixture has one")
    func noauthIsNone() async throws {
        let result = try await Fixture.importingSnippet(
            items: #"""
            [
                { "name": "f", "auth": { "type": "noauth" }, "item": [] },
                { "name": "r", "request": { "auth": { "type": "noauth" } } }
            ]
            """#,
            extraKeys: #""auth": { "type": "noauth" },"#
        )
        let collection = try #require(result.collection)

        #expect(collection.auth == .none)
        #expect(collection.children.first?.folder?.auth == Auth.none)
        #expect(collection.requests.first?.auth == Auth.none)
    }

    @Test("Basic keeps its username and sends its password to the secret store")
    func mapsBasic() async throws {
        let store = InMemorySecretStore()
        let collection = try #require(await Fixture.importing(Self.helpers, secretStore: store).collection)

        guard case .basic(let basic) = try collection.request(named: "basicAuth").auth else {
            Issue.record("Expected Basic auth")
            return
        }

        #expect(basic.username == "abhijit")
        #expect(await Self.stored(basic.password, in: store) == "kane")
    }

    @Test("Bearer sends its token to the secret store")
    func mapsBearer() async throws {
        let store = InMemorySecretStore()
        let collection = try #require(await Fixture.importing(Self.helpers, secretStore: store).collection)

        guard case .bearer(let bearer) = try collection.request(named: "test bearer auth success").auth else {
            Issue.record("Expected Bearer auth")
            return
        }

        #expect(await Self.stored(bearer.token, in: store) == "wkjehbxoqnunc2k3")
    }

    @Test("Digest is stored by kind, with its password in the secret store, and counted as unsupported")
    func mapsDigest() async throws {
        let store = InMemorySecretStore()
        let result = try await Fixture.importing(Self.helpers, secretStore: store)
        let collection = try #require(result.collection)

        guard case .digest(let digest) = try collection.request(named: "DigestAuth").auth else {
            Issue.record("Expected Digest auth")
            return
        }

        #expect(digest.username == "abhijit")
        #expect(await Self.stored(digest.password, in: store) == "kane")
        #expect(result.imported.unsupportedAuth[.digest] == 1)
    }

    @Test("OAuth2 is stored by kind, with its four credentials in the secret store, and counted as unsupported")
    func mapsOAuth2() async throws {
        let store = InMemorySecretStore()
        let result = try await Fixture.importing(Self.helpers, secretStore: store)
        let collection = try #require(result.collection)

        guard case .oauth2(let oauth2) = collection.requests[1].auth else {
            Issue.record("Expected OAuth2 auth")
            return
        }

        #expect(oauth2.grantType == .implicit)
        #expect(oauth2.authorizationURL == "https://foo.com/au")
        #expect(oauth2.accessTokenURL == "https://foo.com/at")
        #expect(oauth2.callbackURL == "https://foo.com/cb")
        #expect(oauth2.clientID == "uniqueClientIdentifier")
        #expect(oauth2.scope == "all")
        #expect(oauth2.username == "postman")
        #expect(await Self.stored(oauth2.clientSecret, in: store) == "secretClientValue")
        #expect(await Self.stored(oauth2.password, in: store) == "randomSecretString")
        #expect(await Self.stored(oauth2.accessToken, in: store) == "secretToken")
        #expect(await Self.stored(oauth2.refreshToken, in: store) == "refreshToken")
        #expect(result.imported.unsupportedAuth[.oauth2] == 1)
    }

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
        let result = try await Self.requestAuth(#"""
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
        let result = try await Self.requestAuth(#"""
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
        #expect(await Self.stored(apiKey.value, in: store) == "abc")
        #expect(result.imported.unsupportedAuth[.apiKey] == 1)
    }

    @Test("An API key with no location goes in a header, Postman's default")
    func apiKeyDefaultsToHeader() async throws {
        let result = try await Self.requestAuth(#"{ "type": "apikey", "apikey": [{ "key": "key", "value": "a" }] }"#)

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
        #expect(await Self.stored(sigV4.accessKeyID, in: store) == "AK")
        #expect(await Self.stored(sigV4.secretAccessKey, in: store) == "SK")
        #expect(await Self.stored(sigV4.sessionToken, in: store) == "ST")
        #expect(result.imported.unsupportedAuth[.awsSigV4] == 1)
    }

    @Test("OAuth 1.0 has no Moth kind, so it's No Auth, counted, and its secrets go nowhere")
    func dropsOAuth1() async throws {
        let result = try await Fixture.importing("postman-collection-transformer/v2.1.0/nestedEntities.json")

        let collection = try #require(result.collection)

        #expect(try collection.request(named: "OAuth1").auth == Auth.none)
        #expect(result.skipped.auth == [.oauth1: 1])
    }

    @Test(
        "Each type Moth has no kind for is No Auth and counted, from a snippet because no licensed fixture has one",
        arguments: [
            ("hawk", PostmanAuthKind.hawk),
            ("ntlm", .ntlm),
            ("edgegrid", .edgeGrid),
            ("jwt", .other("jwt"))
        ]
    )
    func dropsAuthWithNoKind(type: String, kind: PostmanAuthKind) async throws {
        let result = try await Self.requestAuth(#"""
        { "type": "\#(type)", "\#(type)": [{ "key": "password", "value": "hidden" }] }
        """#)

        #expect(result.collection?.requests.first?.auth == Auth.none)
        #expect(result.skipped.auth == [kind: 1])
        #expect(result.secrets.isEmpty)
    }

    @Test("Collection and folder auth map, and their credentials reach the secret store")
    func mapsCollectionAndFolderAuth() async throws {
        let store = InMemorySecretStore()
        let result = try await Fixture.importing(
            "postman-collection-transformer/v2.1.0/nestedEntities.json",
            secretStore: store
        )
        let collection = try #require(result.collection)
        let folder = try #require(collection.children.first?.folder)

        guard case .basic(let collectionAuth) = collection.auth, case .basic(let folderAuth) = folder.auth else {
            Issue.record("Expected Basic auth on the collection and the folder")
            return
        }

        #expect(collectionAuth.username == "{{username}}")
        #expect(folderAuth.username == "{{username}}")
        #expect(await Self.stored(collectionAuth.password, in: store) == "{{token}}")
        #expect(await Self.stored(folderAuth.password, in: store) == "{{token}}")
    }

}
