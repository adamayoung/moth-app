//  RequestSenderAWSSigV4Tests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Testing

struct RequestSenderAWSSigV4Tests {

    private let accessKey = SecretReference(identifier: "access")
    private let secretKey = SecretReference(identifier: "secret")
    private let sessionToken = SecretReference(identifier: "token")
    private let secretStore: any SecretStore = InMemorySecretStore()

    private var auth: AWSSigV4Auth {
        AWSSigV4Auth(
            accessKeyID: accessKey,
            secretAccessKey: secretKey,
            sessionToken: sessionToken,
            region: "{{region}}",
            service: "{{service}}"
        )
    }

    private func store(accessKey access: String, secretKey secret: String, token: String) async throws {
        try await secretStore.save(access, for: accessKey.identifier)
        try await secretStore.save(secret, for: secretKey.identifier)
        try await secretStore.save(token, for: sessionToken.identifier)
    }

    private func request(_ auth: Auth) -> Request {
        Request(name: "Signed", urlTemplate: "https://example.amazonaws.com/", auth: auth)
    }

    @Test("Variables resolve in all five fields before the signature is made")
    func variablesResolveInAllFields() async throws {
        try await store(accessKey: "{{key}}", secretKey: "{{secret}}", token: "{{token}}")
        let templated = RecordingTransport()
        let sender = RequestSender(transport: templated, secretStore: secretStore, now: { .distantPast })

        _ = await sender.send(
            OutgoingRequest(request: request(.awsSigV4(auth))),
            scopes: VariableScopes(environment: [
                .plain("key", "AKIDEXAMPLE"), .plain("secret", "shh"), .plain("token", "tok"),
                .plain("region", "eu-west-2"), .plain("service", "execute-api")
            ])
        )

        let literal = RecordingTransport()
        try await store(accessKey: "AKIDEXAMPLE", secretKey: "shh", token: "tok")
        let plain = AWSSigV4Auth(
            accessKeyID: accessKey,
            secretAccessKey: secretKey,
            sessionToken: sessionToken,
            region: "eu-west-2",
            service: "execute-api"
        )
        _ = await RequestSender(transport: literal, secretStore: secretStore, now: { .distantPast })
            .send(OutgoingRequest(request: request(.awsSigV4(plain))), scopes: VariableScopes())

        let sent = try #require(templated.requests.first)
        #expect(sent.value(forHTTPHeaderField: "X-Amz-Security-Token") == "tok")
        #expect(sent.value(forHTTPHeaderField: "Authorization")?.contains("AKIDEXAMPLE/") == true)
        #expect(sent.value(forHTTPHeaderField: "Authorization")?.contains("/eu-west-2/execute-api/") == true)
        #expect(
            sent.value(forHTTPHeaderField: "Authorization")
                == literal.requests.first?.value(forHTTPHeaderField: "Authorization")
        )
    }

    @Test("A variable that resolves to nothing stops the send with the missing field error")
    func variableResolvingToEmpty() async throws {
        try await store(accessKey: "k", secretKey: "s", token: "t")
        let transport = RecordingTransport()
        let sender = RequestSender(transport: transport, secretStore: secretStore)

        let result = await sender.send(
            OutgoingRequest(request: request(.awsSigV4(auth))),
            scopes: VariableScopes(environment: [.plain("region", ""), .plain("service", "s3")])
        )

        guard case .failed(let failure, _) = result else {
            Issue.record("Expected the send to stop, got \(result)")
            return
        }
        #expect(failure.kind == .notSent)
        #expect(failure.description == "AWS Signature needs an access key, secret key, region and service.")
        #expect(transport.requests.isEmpty)
    }

    @Test("Each send signs afresh with the current time")
    func eachSendSignsAfresh() async throws {
        try await store(accessKey: "k", secretKey: "s", token: "t")
        let transport = RecordingTransport()
        let clock = SteppingClock([
            Date(timeIntervalSince1970: 1_440_938_160),
            Date(timeIntervalSince1970: 1_440_938_161)
        ])
        let sender = RequestSender(transport: transport, secretStore: secretStore, now: { clock.next() })
        let outgoing = OutgoingRequest(request: request(.awsSigV4(auth)))
        let scopes = VariableScopes(environment: [.plain("region", "r"), .plain("service", "a")])

        _ = await sender.send(outgoing, scopes: scopes)
        _ = await sender.send(outgoing, scopes: scopes)

        #expect(transport.requests.map { $0.value(forHTTPHeaderField: "X-Amz-Date") } == [
            "20150830T123600Z", "20150830T123601Z"
        ])
        #expect(
            transport.requests.first?.value(forHTTPHeaderField: "Authorization")
                != transport.requests.last?.value(forHTTPHeaderField: "Authorization")
        )
    }

    @Test("A typed credential signs without reaching the Keychain")
    func typedCredentialSigns() async throws {
        let transport = RecordingTransport()
        let sender = RequestSender(transport: transport, secretStore: secretStore)
        let plain = AWSSigV4Auth(accessKeyID: accessKey, secretAccessKey: secretKey, region: "r", service: "a")

        _ = await sender.send(
            OutgoingRequest(
                request: request(.awsSigV4(plain)),
                typedCredentials: [
                    CredentialWrite(reference: accessKey, value: "typed"),
                    CredentialWrite(reference: secretKey, value: "secret")
                ]
            ),
            scopes: VariableScopes()
        )

        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization")?.contains("typed/") == true)
        #expect(try await secretStore.value(for: accessKey.identifier) == nil)
    }

    @Test(
        "A folder's or collection's AWS Signature reaches a request set to Inherit, signed",
        arguments: [true, false]
    )
    func inherited(fromFolder: Bool) async throws {
        try await store(accessKey: "k", secretKey: "s", token: "t")
        let plain = AWSSigV4Auth(
            accessKeyID: accessKey,
            secretAccessKey: secretKey,
            sessionToken: sessionToken,
            region: "r",
            service: "a"
        )
        var stored = request(.inherit)
        let folder = Folder(
            name: "F",
            auth: fromFolder ? .awsSigV4(plain) : .inherit,
            children: [CollectionItem(sortOrder: 0, node: .request(stored))]
        )
        let collection = RequestCollection(
            name: "C",
            auth: fromFolder ? .none : .awsSigV4(plain),
            children: [CollectionItem(sortOrder: 0, node: .folder(folder))]
        )
        let transport = RecordingTransport()

        stored.auth = collection.effectiveAuth(of: stored)
        _ = await RequestSender(transport: transport, secretStore: secretStore)
            .send(OutgoingRequest(request: stored), scopes: VariableScopes())

        let sent = try #require(transport.requests.first)
        #expect(sent.value(forHTTPHeaderField: "Authorization")?.hasPrefix("AWS4-HMAC-SHA256 Credential=k/") == true)
        #expect(sent.value(forHTTPHeaderField: "X-Amz-Security-Token") == "t")
    }

}

private final nonisolated class SteppingClock: @unchecked Sendable {

    private let lock = NSLock()
    private var dates: [Date]

    init(_ dates: [Date]) {
        self.dates = dates
    }

    func next() -> Date {
        lock.withLock { dates.removeFirst() }
    }

}
