//  PostmanAuthTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import PostmanKit
import Testing

struct PostmanAuthTests {

    @Test("Auth decodes at collection, folder and request level")
    func decodesEachLevel() throws {
        let collection = try Fixture.collection("postman-collection-transformer/v2.1.0/nestedEntities.json")

        let collectionAuth = try #require(collection.auth)
        #expect(collectionAuth.type == .basic)
        #expect(collectionAuth.parameters.map(\.key) == ["username", "password"])
        #expect(collectionAuth.parameters.map(\.value) == [.string("{{username}}"), .string("{{token}}")])

        let folder = try #require(collection.items.first?.folder)
        #expect(folder.auth?.type == .basic)

        let request = try #require(collection.request(named: "OAuth1"))
        #expect(request.auth?.type == .oauth1)
    }

    @Test("Bearer auth keeps its token")
    func decodesBearerToken() throws {
        let collection = try Fixture.collection("postman-collection-transformer/v2.1.0/helpers.json")

        let auth = try #require(collection.request(named: "test bearer auth success")?.auth)

        #expect(auth.type == .bearer)
        let token = try #require(auth.parameters.only)
        #expect(token.key == "token")
        #expect(token.value == .string("wkjehbxoqnunc2k3"))
        #expect(token.type == "string")
    }

    @Test("An auth value that isn't a string keeps its type")
    func keepsNonStringValue() throws {
        let collection = try Fixture.collection("postman-collection-transformer/v2.1.0/helpers.json")

        let auth = try #require(collection.request(named: "OAuth")?.auth)

        let flag = try #require(auth.parameters.first { $0.key == "encodeOAuthSign" })
        #expect(flag.value == .bool(true))
    }

    @Test("An unknown auth type keeps its name and its parameters")
    func keepsUnknownType() throws {
        let json = """
        { "type": "jwt", "jwt": [{ "key": "algorithm", "value": "HS256", "type": "string" }] }
        """

        let auth = try JSONDecoder().decode(PostmanAuth.self, from: Data(json.utf8))

        #expect(auth.type == .unknown("jwt"))
        #expect(auth.parameters.map(\.key) == ["algorithm"])
    }

    @Test("An unknown auth type whose payload isn't a list keeps its name")
    func keepsUnknownTypeWithObjectPayload() throws {
        let json = #"{ "type": "customAuth", "customAuth": { "token": "x" } }"#

        let auth = try JSONDecoder().decode(PostmanAuth.self, from: Data(json.utf8))

        #expect(auth.type == .unknown("customAuth"))
        #expect(auth.parameters.isEmpty)
    }

    @Test("No auth decodes with the object payload the published schema allows")
    func decodesNoAuthObjectPayload() throws {
        let json = #"{ "type": "noauth", "noauth": {} }"#

        let auth = try JSONDecoder().decode(PostmanAuth.self, from: Data(json.utf8))

        #expect(auth.type == .noauth)
        #expect(auth.parameters.isEmpty)
    }

    @Test("A known auth type whose parameters aren't a list is rejected, so credentials aren't lost silently")
    func rejectsKnownTypeWithObjectPayload() {
        let json = #"{ "type": "basic", "basic": { "username": "x" } }"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PostmanAuth.self, from: Data(json.utf8))
        }
    }

    @Test(
        "Every type in the published schema is recognised",
        arguments: [
            ("apikey", PostmanAuthType.apikey),
            ("awsv4", .awsv4),
            ("basic", .basic),
            ("bearer", .bearer),
            ("digest", .digest),
            ("edgegrid", .edgegrid),
            ("hawk", .hawk),
            ("noauth", .noauth),
            ("ntlm", .ntlm),
            ("oauth1", .oauth1),
            ("oauth2", .oauth2)
        ]
    )
    func recognisesSchemaTypes(name: String, expected: PostmanAuthType) throws {
        let json = #"{ "type": "\#(name)" }"#

        let auth = try JSONDecoder().decode(PostmanAuth.self, from: Data(json.utf8))

        #expect(auth.type == expected)
        #expect(auth.parameters.isEmpty)
    }

}
