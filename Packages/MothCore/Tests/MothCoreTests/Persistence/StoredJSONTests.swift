//  StoredJSONTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import Testing

/// The JSON in a `Data` attribute is frozen with `SchemaV1`, and synced rows are read by older builds. A failure here
/// means a rename in `Domain/` changed the stored format: keep the old spelling with `CodingKeys`.
struct StoredJSONTests {

    private nonisolated static let reference = #"{"identifier":"r"}"#
    private nonisolated static let secret = SecretReference(identifier: "r")

    private nonisolated static let auths: [(Auth, String)] = [
        (.inherit, #"{"inherit":{}}"#),
        (.none, #"{"none":{}}"#),
        (
            .basic(BasicAuth(username: "u", password: secret)),
            #"{"basic":{"_0":{"password":\#(reference),"username":"u"}}}"#
        ),
        (.bearer(BearerAuth(token: secret)), #"{"bearer":{"_0":{"token":\#(reference)}}}"#),
        (
            .apiKey(APIKeyAuth(name: "n", value: secret, location: .header)),
            #"{"apiKey":{"_0":{"location":{"header":{}},"name":"n","value":\#(reference)}}}"#
        ),
        (
            .digest(DigestAuth(username: "u", password: secret)),
            #"{"digest":{"_0":{"password":\#(reference),"username":"u"}}}"#
        ),
        (
            .oauth2(OAuth2Auth(
                grantType: .clientCredentials,
                authorizationURL: "a",
                accessTokenURL: "t",
                callbackURL: "c",
                clientID: "i",
                clientSecret: secret,
                scope: "s",
                username: "u",
                password: secret,
                accessToken: secret,
                refreshToken: secret
            )),
            #"{"oauth2":{"_0":{"accessToken":\#(reference),"accessTokenURL":"t","authorizationURL":"a","#
                + #""callbackURL":"c","clientID":"i","clientSecret":\#(reference),"#
                + #""grantType":{"clientCredentials":{}},"password":\#(reference),"#
                + #""refreshToken":\#(reference),"scope":"s","username":"u"}}}"#
        ),
        (
            .awsSigV4(AWSSigV4Auth(
                accessKeyID: secret,
                secretAccessKey: secret,
                sessionToken: secret,
                region: "r",
                service: "s"
            )),
            #"{"awsSigV4":{"_0":{"accessKeyID":\#(reference),"region":"r","secretAccessKey":\#(reference),"#
                + #""service":"s","sessionToken":\#(reference)}}}"#
        )
    ]

    private nonisolated static let id = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private nonisolated static let idJSON = #""00000000-0000-0000-0000-000000000001""#

    private nonisolated static let bodies: [(RequestBody, String)] = [
        (.none, #"{"none":{}}"#),
        (
            .formData([
                FormDataField(id: id, key: "k", value: .text("v"), contentType: "c", isEnabled: false),
                FormDataField(id: id, key: "f", value: .file(paths: ["/a"]))
            ]),
            #"{"formData":{"_0":[{"contentType":"c","id":\#(idJSON),"isEnabled":false,"key":"k","#
                + #""value":{"text":{"_0":"v"}}},{"id":\#(idJSON),"isEnabled":true,"key":"f","#
                + #""value":{"file":{"paths":["/a"]}}}]}}"#
        ),
        (
            .urlEncoded([KeyValue(id: id, key: "k", value: "v")]),
            #"{"urlEncoded":{"_0":[{"id":\#(idJSON),"isEnabled":true,"key":"k","value":"v"}]}}"#
        ),
        (.raw(content: "c", contentType: "t"), #"{"raw":{"content":"c","contentType":"t"}}"#),
        (.binary(filePath: "/a"), #"{"binary":{"filePath":"/a"}}"#),
        (.graphQL(query: "q", variables: "v"), #"{"graphQL":{"query":"q","variables":"v"}}"#)
    ]

    @Test("Each auth kind's stored JSON is pinned", arguments: auths)
    func authJSONIsPinned(auth: Auth, json: String) throws {
        try #expect(Self.text(of: auth) == json)
        #expect(try StoredJSON.decode(Auth.self, from: Data(json.utf8), default: .inherit) == auth)
    }

    @Test("Each body kind's stored JSON is pinned", arguments: bodies)
    func bodyJSONIsPinned(body: RequestBody, json: String) throws {
        try #expect(Self.text(of: body) == json)
        #expect(try StoredJSON.decode(RequestBody.self, from: Data(json.utf8), default: .none) == body)
    }

    @Test("Stored settings are pinned, with the timeout at full precision")
    func settingsJSONIsPinned() throws {
        let settings = RequestSettings(timeout: .seconds(1), followsRedirects: false, verifiesTLS: true)
        let json = #"{"followsRedirects":false,"timeout":[0,1000000000000000000],"verifiesTLS":true}"#

        try #expect(Self.text(of: settings) == json)
        #expect(try StoredJSON
            .decode(RequestSettings.self, from: Data(json.utf8), default: RequestSettings()) == settings)
    }

    @Test("A stored method is its raw value, so a custom method is kept")
    func methodJSONIsPinned() throws {
        try #expect(Self.text(of: HTTPMethod(rawValue: "PROPFIND")) == #""PROPFIND""#)
    }

    @Test("A stored request snapshot is pinned")
    func requestJSONIsPinned() throws {
        let request = Request(id: Self.id, name: "n")

        try #expect(Self.text(of: request) == """
        {"auth":{"inherit":{}},"body":{"none":{}},"headers":[],"id":\(Self.idJSON),\
        "method":"GET","name":"n","pathParameters":[],"queryParameters":[],\
        "settings":{"followsRedirects":true,"timeout":[3,4659767778871345152],"verifiesTLS":true},\
        "urlTemplate":"","variables":[]}
        """)
    }

    @Test("A stored variable in a request snapshot is pinned, with a secret as its reference")
    func variableJSONIsPinned() throws {
        let plain = Variable(id: Self.id, name: "n", value: .plain(initial: "i", current: "c"))
        let secret = Variable(id: Self.id, name: "n", value: .secret(Self.secret), isEnabled: false)

        try #expect(Self.text(of: plain) == """
        {"id":\(Self.idJSON),"isEnabled":true,"name":"n","value":{"plain":{"current":"c","initial":"i"}}}
        """)
        try #expect(Self.text(of: secret) == """
        {"id":\(Self.idJSON),"isEnabled":false,"name":"n","value":{"secret":{"_0":\(Self.reference)}}}
        """)
    }

    @Test("Equal values encode to equal bytes, so a write can compare before it assigns")
    func encodingIsStable() throws {
        let auth = DomainFixtures.auths[6]

        #expect(try StoredJSON.encode(auth) == StoredJSON.encode(auth))
    }

    @Test("Stored JSON this build cannot read throws rather than falling back to the default")
    func unreadableJSONThrows() {
        #expect(throws: DecodingError.self) {
            try StoredJSON.decode(Auth.self, from: Data(#"{"ntlm":{}}"#.utf8), default: .inherit)
        }
    }

    @Test("An unset attribute decodes to the default")
    func unsetAttributeDecodesToTheDefault() throws {
        #expect(try StoredJSON.decode(Auth.self, from: nil, default: .none) == .none)
    }

    private static func text(of value: some Encodable) throws -> String {
        try String(decoding: StoredJSON.encode(value), as: UTF8.self)
    }

}
