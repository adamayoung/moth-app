//  PostmanAuthMappingTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct PostmanAuthMappingTests {

    private static let helpers = "postman-collection-transformer/v2.1.0/helpers.json"

    @Test("A request with no auth entry inherits")
    func unsetRequestInherits() async throws {
        let collection = try await Fixture.collection("postman-code-generators/basicCollection.json")

        #expect(collection.requests.allSatisfy { $0.auth == .inherit })
    }

    @Test("A request whose auth is null inherits, because PostmanKit reads null as no entry")
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
        #expect(await Fixture.stored(basic.password, in: store) == "kane")
    }

    @Test(
        "An empty or absent password still saves, because Basic and Digest send a username alone",
        arguments: [
            #"{ "type": "basic", "basic": [{ "key": "password", "value": "" }] }"#,
            #"{ "type": "basic", "basic": [{ "key": "username", "value": "key" }] }"#,
            #"{ "type": "digest", "digest": [{ "key": "password", "value": "" }] }"#
        ]
    )
    func keepsEmptyPassword(auth: String) async throws {
        let store = InMemorySecretStore()
        let result = try await Fixture.importingSnippet(
            items: #"[{ "name": "a", "request": { "auth": \#(auth) } }]"#,
            secretStore: store
        )

        let reference = try #require(result.secrets.first)

        #expect(await Fixture.stored(reference, in: store) == "")
    }

    @Test("An empty Bearer token saves nothing, so Moth reports it as missing")
    func emptyBearerTokenSavesNothing() async throws {
        let result = try await Fixture.importingAuth(#"""
        { "type": "bearer", "bearer": [{ "key": "token", "value": "" }] }
        """#)

        #expect(result.secrets.isEmpty)
    }

    @Test("Bearer sends its token to the secret store")
    func mapsBearer() async throws {
        let store = InMemorySecretStore()
        let collection = try #require(await Fixture.importing(Self.helpers, secretStore: store).collection)

        guard case .bearer(let bearer) = try collection.request(named: "test bearer auth success").auth else {
            Issue.record("Expected Bearer auth")
            return
        }

        #expect(await Fixture.stored(bearer.token, in: store) == "wkjehbxoqnunc2k3")
    }

    @Test("Digest maps with its password in the secret store, ready to send, and isn't counted as unsupported")
    func mapsDigest() async throws {
        let store = InMemorySecretStore()
        let result = try await Fixture.importing(Self.helpers, secretStore: store)
        let collection = try #require(result.collection)

        guard case .digest(let digest) = try collection.request(named: "DigestAuth").auth else {
            Issue.record("Expected Digest auth")
            return
        }

        #expect(digest.username == "abhijit")
        #expect(await Fixture.stored(digest.password, in: store) == "kane")
        #expect(result.imported.unsupportedAuth == [.oauth2: 1])
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
        #expect(await Fixture.stored(oauth2.clientSecret, in: store) == "secretClientValue")
        #expect(await Fixture.stored(oauth2.password, in: store) == "randomSecretString")
        #expect(await Fixture.stored(oauth2.accessToken, in: store) == "secretToken")
        #expect(await Fixture.stored(oauth2.refreshToken, in: store) == "refreshToken")
        #expect(result.imported.unsupportedAuth[.oauth2] == 1)
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
        let result = try await Fixture.importingAuth(#"""
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
        #expect(await Fixture.stored(collectionAuth.password, in: store) == "{{token}}")
        #expect(await Fixture.stored(folderAuth.password, in: store) == "{{token}}")
    }

}
