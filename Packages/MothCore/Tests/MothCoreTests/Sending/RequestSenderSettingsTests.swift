//  RequestSenderSettingsTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Testing

struct RequestSenderSettingsTests {

    private static let unverified = RequestSettings(followsRedirects: false, verifiesTLS: false)

    private static func request(_ url: String = "https://example.com/users", settings: RequestSettings) -> Request {
        Request(name: "List", urlTemplate: url, auth: .none, settings: settings)
    }

    private func send(_ request: Request, through transport: some HTTPTransport) async -> SendResult {
        await RequestSender(transport: transport, secretStore: InMemorySecretStore())
            .send(OutgoingRequest(request: request), scopes: VariableScopes())
    }

    private func notes(of result: SendResult) throws -> [ResponseNote] {
        guard case .response(let response) = result else {
            Issue.record("Expected a response, got \(result)")
            throw CancellationError()
        }
        return response.notes
    }

    @Test("The request's settings go to the transport as the send's policy")
    func settingsBecomeThePolicy() async {
        let transport = RecordingTransport()

        _ = await send(Self.request(settings: Self.unverified), through: transport)

        #expect(transport.policies == [SendPolicy(followsRedirects: false, verifiesTLS: false)])
    }

    @Test("The defaults follow redirects, verify TLS and leave Authorization and Cookie behind on another origin")
    func defaultPolicy() async {
        let transport = RecordingTransport()

        _ = await send(Self.request(settings: RequestSettings()), through: transport)

        #expect(transport.policies == [SendPolicy()])
        #expect(transport.policies.first?.credentialHeaders == ["authorization", "cookie"])
    }

    @Test("A Digest answer goes with the same policy")
    func digestAnswerUsesThePolicy() async {
        let password = SecretReference(identifier: "digest-password")
        let secrets = InMemorySecretStore()
        await secrets.save("Circle of Life", for: password.identifier)
        let challenge = HTTPResponse(
            status: 401,
            headers: ["WWW-Authenticate": #"Digest realm="api", nonce="n", qop="auth", algorithm=SHA-256"#],
            body: Data()
        )
        let transport = ScriptedTransport(challenge, HTTPResponse(status: 200, headers: [:], body: Data()))
        var request = Self.request(settings: Self.unverified)
        request.auth = .digest(DigestAuth(username: "ada", password: password))

        _ = await RequestSender(transport: transport, secretStore: secrets)
            .send(OutgoingRequest(request: request), scopes: VariableScopes())

        #expect(transport.policies.count == 2)
        #expect(transport.policies.allSatisfy { !$0.followsRedirects && !$0.verifiesTLS })
    }

    @Test("With verification off, the response says it was sent without verifying the certificate")
    func unverifiedNote() async throws {
        let result = await send(Self.request(settings: Self.unverified), through: RecordingTransport())

        #expect(try notes(of: result) == [.sentWithoutTLSVerification])
    }

    @Test("With verification on, there's no note")
    func verifiedHasNoNote() async throws {
        let result = await send(Self.request(settings: RequestSettings()), through: RecordingTransport())

        #expect(try notes(of: result).isEmpty)
    }

    @Test("With verification off, plain HTTP gets the note too, because a redirect can pass through HTTPS")
    func plainHTTPHasTheNote() async throws {
        let request = Self.request("http://example.com/users", settings: Self.unverified)

        let result = await send(request, through: RecordingTransport())

        #expect(try notes(of: result) == [.sentWithoutTLSVerification])
    }

}
