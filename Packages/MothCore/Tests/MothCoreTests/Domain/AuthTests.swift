//  AuthTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct AuthTests {

    private let password = SecretReference(identifier: "password")
    private let token = SecretReference(identifier: "token")

    @Test("Inherit and no auth are different kinds")
    func inheritIsNotNone() {
        #expect(Auth.inherit != .none)
    }

    @Test("Basic keeps its username and a reference to its password")
    func basicKeepsItsFields() {
        guard case .basic(let basic) = Auth.basic(BasicAuth(username: "ada", password: password)) else {
            Issue.record("Expected Basic auth")
            return
        }

        #expect(basic.username == "ada")
        #expect(basic.password == password)
    }

    @Test("Bearer keeps a reference to its token")
    func bearerKeepsItsToken() {
        guard case .bearer(let bearer) = Auth.bearer(BearerAuth(token: token)) else {
            Issue.record("Expected Bearer auth")
            return
        }

        #expect(bearer.token == token)
    }

    @Test("API key keeps its name, location and a reference to its value", arguments: [APIKeyLocation.header, .query])
    func apiKeyKeepsItsFields(location: APIKeyLocation) {
        let apiKey = APIKeyAuth(name: "X-API-Key", value: token, location: location)

        guard case .apiKey(let kept) = Auth.apiKey(apiKey) else {
            Issue.record("Expected API key auth")
            return
        }

        #expect(kept.name == "X-API-Key")
        #expect(kept.value == token)
        #expect(kept.location == location)
    }

    @Test("Digest keeps its username and a reference to its password")
    func digestKeepsItsFields() {
        guard case .digest(let digest) = Auth.digest(DigestAuth(username: "ada", password: password)) else {
            Issue.record("Expected Digest auth")
            return
        }

        #expect(digest.username == "ada")
        #expect(digest.password == password)
    }

    @Test(
        "OAuth2 keeps its grant, endpoints and references to its credentials",
        arguments: [
            OAuth2GrantType.authorizationCode,
            .authorizationCodeWithPKCE,
            .implicit,
            .passwordCredentials,
            .clientCredentials
        ]
    )
    func oauth2KeepsItsFields(grantType: OAuth2GrantType) {
        let clientSecret = SecretReference(identifier: "client-secret")
        let refreshToken = SecretReference(identifier: "refresh-token")
        let oauth2 = OAuth2Auth(
            grantType: grantType,
            authorizationURL: "https://example.com/authorize",
            accessTokenURL: "https://example.com/token",
            callbackURL: "moth://callback",
            clientID: "moth",
            clientSecret: clientSecret,
            scope: "read write",
            username: "ada",
            password: password,
            accessToken: token,
            refreshToken: refreshToken
        )

        guard case .oauth2(let kept) = Auth.oauth2(oauth2) else {
            Issue.record("Expected OAuth2 auth")
            return
        }

        #expect(kept.grantType == grantType)
        #expect(kept.authorizationURL == "https://example.com/authorize")
        #expect(kept.accessTokenURL == "https://example.com/token")
        #expect(kept.callbackURL == "moth://callback")
        #expect(kept.clientID == "moth")
        #expect(kept.clientSecret == clientSecret)
        #expect(kept.scope == "read write")
        #expect(kept.username == "ada")
        #expect(kept.password == password)
        #expect(kept.accessToken == token)
        #expect(kept.refreshToken == refreshToken)
    }

    @Test("AWS SigV4 keeps its region, service and references to its keys")
    func awsSigV4KeepsItsFields() {
        let accessKeyID = SecretReference(identifier: "access-key-id")
        let secretAccessKey = SecretReference(identifier: "secret-access-key")
        let sessionToken = SecretReference(identifier: "session-token")
        let sigV4 = AWSSigV4Auth(
            accessKeyID: accessKeyID,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken,
            region: "eu-west-2",
            service: "execute-api"
        )

        guard case .awsSigV4(let kept) = Auth.awsSigV4(sigV4) else {
            Issue.record("Expected AWS SigV4 auth")
            return
        }

        #expect(kept.accessKeyID == accessKeyID)
        #expect(kept.secretAccessKey == secretAccessKey)
        #expect(kept.sessionToken == sessionToken)
        #expect(kept.region == "eu-west-2")
        #expect(kept.service == "execute-api")
    }

}
