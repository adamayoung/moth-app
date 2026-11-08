//  RequestSenderCredentialHeaderTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Testing

/// What the policy names stays behind on a redirect to another origin; `URLSessionRedirectTests` proves that on the
/// wire.
struct RequestSenderCredentialHeaderTests {

    private let secret = SecretReference(identifier: "secret")
    private let secretStore = InMemorySecretStore()

    init() async {
        await secretStore.save("s3cret", for: secret.identifier)
    }

    private func send(_ request: Request, through transport: RecordingTransport = RecordingTransport()) async
    -> RecordingTransport {
        _ = await RequestSender(transport: transport, secretStore: secretStore)
            .send(OutgoingRequest(request: request), scopes: VariableScopes())
        return transport
    }

    private func request(auth: Auth, headers: [KeyValue] = []) -> Request {
        Request(name: "List", urlTemplate: "https://api.example.com/users", headers: headers, auth: auth)
    }

    @Test("An API Key sent in a header is named as a credential, beside Authorization and Cookie")
    func apiKeyHeader() async {
        let auth = Auth.apiKey(APIKeyAuth(name: "X-API-Key", value: secret, location: .header))

        let transport = await send(request(auth: auth))

        #expect(transport.policies.map(\.credentialHeaders) == [["authorization", "cookie", "x-api-key"]])
        #expect(transport.requests.first?.value(forHTTPHeaderField: "X-API-Key") == "s3cret")
    }

    @Test("An API Key sent in the query names no header, and goes where the URL goes")
    func apiKeyQuery() async throws {
        let auth = Auth.apiKey(APIKeyAuth(name: "api_key", value: secret, location: .query))

        let transport = await send(request(auth: auth))

        #expect(transport.policies.map(\.credentialHeaders) == [SendPolicy.standardCredentialHeaders])
        let url = try #require(transport.requests.first?.url)
        #expect(url.query == "api_key=s3cret")
    }

    @Test("An AWS session token is named as a credential", arguments: [true, false])
    func awsSessionToken(hasSessionToken: Bool) async {
        let auth = Auth.awsSigV4(AWSSigV4Auth(
            accessKeyID: secret,
            secretAccessKey: secret,
            sessionToken: hasSessionToken ? secret : nil,
            region: "eu-west-2",
            service: "execute-api"
        ))

        let transport = await send(request(auth: auth))

        let expected = SendPolicy.standardCredentialHeaders.union(hasSessionToken ? ["x-amz-security-token"] : [])
        #expect(transport.policies.map(\.credentialHeaders) == [expected])
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization")?.hasPrefix("AWS4-HMAC") == true)
    }

    @Test("Basic and Bearer still send their Authorization, and name nothing beyond the standard pair")
    func authorizationOnlyKinds() async {
        let kinds: [(Auth, String)] = [
            (.basic(BasicAuth(username: "ada", password: secret)), "Basic YWRhOnMzY3JldA=="),
            (.bearer(BearerAuth(token: secret)), "Bearer s3cret")
        ]

        for (auth, authorization) in kinds {
            let transport = await send(request(auth: auth))

            #expect(transport.policies.map(\.credentialHeaders) == [SendPolicy.standardCredentialHeaders])
            #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == authorization)
        }
    }

    @Test("Digest sends no Authorization until challenged, and names nothing beyond the standard pair")
    func digest() async {
        let transport = await send(request(auth: .digest(DigestAuth(username: "ada", password: secret))))

        #expect(transport.policies.map(\.credentialHeaders) == [SendPolicy.standardCredentialHeaders])
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("OAuth 2.0 Client Credentials still sends its token, and names nothing beyond the standard pair")
    func oauth2ClientCredentials() async {
        await secretStore.save("s3cret", for: RequestSenderOAuth2Tests.clientSecret.identifier)
        let transport = ScriptedTransport(RequestSenderOAuth2Tests.issued, RequestSenderOAuth2Tests.accepted)

        _ = await RequestSender(transport: transport, secretStore: secretStore)
            .send(OutgoingRequest(request: request(auth: RequestSenderOAuth2Tests.oauth2())), scopes: VariableScopes())

        #expect(transport.policies.last?.credentialHeaders == SendPolicy.standardCredentialHeaders)
        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer issued-tok")
    }

    @Test("An API Key inherited from a folder or the collection is named the same way", arguments: [true, false])
    func inheritedAPIKey(fromFolder: Bool) async throws {
        let apiKey = Auth.apiKey(APIKeyAuth(name: "X-API-Key", value: secret, location: .header))
        let stored = request(auth: .inherit)
        let folder = Folder(
            name: "Folder",
            auth: fromFolder ? apiKey : .inherit,
            children: [CollectionItem(sortOrder: 0, node: .request(stored))]
        )
        let collection = RequestCollection(
            name: "API",
            auth: fromFolder ? .none : apiKey,
            children: [CollectionItem(sortOrder: 0, node: .folder(folder))]
        )
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection]))
        let tree = try CollectionTree(savedIn: dataModel)
        let outgoing = try RequestDraft(stored).outgoing(from: stored, in: tree)

        let transport = RecordingTransport()
        _ = await RequestSender(transport: transport, secretStore: secretStore)
            .send(outgoing, scopes: VariableScopes())

        #expect(transport.requests.first?.value(forHTTPHeaderField: "X-API-Key") == "s3cret")
        #expect(transport.policies.map(\.credentialHeaders) == [["authorization", "cookie", "x-api-key"]])
    }

    @Test("A header row typed into the request is sent as written and not named as a credential")
    func manualHeaderRow() async {
        let transport = await send(request(auth: .none, headers: [KeyValue(key: "X-API-Key", value: "typed")]))

        #expect(transport.policies.map(\.credentialHeaders) == [SendPolicy.standardCredentialHeaders])
        #expect(transport.requests.first?.value(forHTTPHeaderField: "X-API-Key") == "typed")
    }

}
