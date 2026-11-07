//  RequestBuilderAWSSigV4Tests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CryptoKit
import Foundation
import MothCore
import Testing

struct RequestBuilderAWSSigV4Tests {

    private nonisolated static let sendTime = Date(timeIntervalSince1970: 1_440_938_160)
    private static let emptyPayloadHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    private let accessKey = SecretReference(identifier: "access")
    private let secretKey = SecretReference(identifier: "secret")
    private let sessionToken = SecretReference(identifier: "token")

    private var builder: RequestBuilder {
        RequestBuilder(multipartBoundary: { "fixed" }, now: { Self.sendTime })
    }

    private func auth(service: String = "s3", sessionToken: SecretReference? = nil) -> Auth {
        .awsSigV4(AWSSigV4Auth(
            accessKeyID: accessKey,
            secretAccessKey: secretKey,
            sessionToken: sessionToken,
            region: "us-east-1",
            service: service
        ))
    }

    private func build(
        method: HTTPMethod = .post,
        url: String = "https://example.amazonaws.com/",
        queryParameters: [KeyValue] = [],
        headers: [KeyValue] = [],
        body: RequestBody = .none,
        auth: Auth? = nil,
        credentials: [SecretReference: String]? = nil,
        unresolved: [UnresolvedVariable] = []
    ) async throws -> BuiltRequest {
        try await builder.build(ResolvedRequest(
            method: method,
            url: url,
            queryParameters: queryParameters,
            headers: headers,
            body: body,
            auth: auth ?? self.auth(),
            credentials: credentials ?? [accessKey: "AKIDEXAMPLE", secretKey: "secret"],
            unresolved: unresolved
        ))
    }

    private func authorization(of built: BuiltRequest) throws -> String {
        try #require(built.urlRequest.value(forHTTPHeaderField: "Authorization"))
    }

    @Test("A signature adds no notice")
    func noNotice() async throws {
        #expect(try await build().notices.isEmpty)
    }

    @Test("A form-data boundary is signed as sent")
    func formData() async throws {
        let built = try await build(body: .formData([FormDataField(key: "a", value: .text("b"))]))

        let body = try #require(built.urlRequest.httpBody)
        #expect(String(bytes: body, encoding: .utf8)?.contains("--fixed") == true)
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Amz-Content-Sha256") == Self.hash(body))
        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type")?.contains("boundary=fixed") == true)
        #expect(try authorization(of: built).contains("SignedHeaders=content-type;host;"))
    }

    @Test("A binary body is left out of the send, so the signature covers no body")
    func binaryIsSignedAsSent() async throws {
        let built = try await build(body: .binary(filePath: "/tmp/file"))

        #expect(built.urlRequest.httpBody == nil)
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Amz-Content-Sha256") == Self.emptyPayloadHash)
        #expect(built.notices == [.unsupportedBody(.binary)])
    }

    @Test("The date is the send time")
    func dateIsSendTime() async throws {
        let built = try await build()

        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Amz-Date") == "20150830T123600Z")
        #expect(try authorization(of: built).contains("/20150830/us-east-1/s3/aws4_request"))
    }

    @Test("A query row is signed, because the signature follows the final URL")
    func queryRowsAreSigned() async throws {
        let plain = try await build()
        let queried = try await build(queryParameters: [KeyValue(key: "a", value: "b")])

        #expect(try authorization(of: plain) != authorization(of: queried))
    }

    @Test("A header row is signed")
    func headerRowsAreSigned() async throws {
        let built = try await build(headers: [KeyValue(key: "X-Custom", value: "1")])

        #expect(try authorization(of: built).contains("x-custom"))
    }

    @Test("A credential with no value stops the build", arguments: ["access", "secret"])
    func credentialWithNoValue(missing: String) async {
        let credentials = [accessKey: "a", secretKey: "s"].filter { $0.key.identifier != missing }

        await #expect(throws: RequestBuildError.incompleteAWSSignature) {
            _ = try await build(credentials: credentials)
        }
    }

    @Test("A session token with no value is left off")
    func sessionTokenWithNoValue() async throws {
        let built = try await build(auth: auth(sessionToken: sessionToken))

        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Amz-Security-Token") == nil)
    }

    @Test(
        "A row the signature replaces isn't reported for its unresolved variable",
        arguments: ["Authorization", "X-Amz-Date", "x-amz-content-sha256", "X-Amz-Security-Token"]
    )
    func replacedRowIsNotReported(name: String) async throws {
        let credentials = [accessKey: "a", secretKey: "s", sessionToken: "t"]

        let built = try await builder.build(rowWithUndefinedVariable(named: name, credentials: credentials))

        #expect(built.unresolved.isEmpty)
    }

    @Test("A session token row stays reported when the signature sets no token")
    func tokenRowStaysWithoutAToken() async throws {
        let built = try await builder.build(rowWithUndefinedVariable(
            named: "X-Amz-Security-Token",
            credentials: [accessKey: "a", secretKey: "s"]
        ))

        #expect(built.unresolved.map(\.name) == ["missing"])
    }

    private func rowWithUndefinedVariable(
        named name: String,
        credentials: [SecretReference: String]
    ) async throws -> ResolvedRequest {
        try await VariableResolver(secretStore: InMemorySecretStore()).resolve(
            Request(
                name: "Row",
                urlTemplate: "https://example.amazonaws.com",
                headers: [KeyValue(key: name, value: "{{missing}}")]
            ),
            collection: [],
            environment: [],
            globals: []
        ).withAuth(auth(sessionToken: credentials[sessionToken] == nil ? nil : sessionToken), credentials)
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

}

private nonisolated extension ResolvedRequest {

    func withAuth(_ auth: Auth, _ credentials: [SecretReference: String]) -> ResolvedRequest {
        var request = self
        request.auth = auth
        request.credentials = credentials
        return request
    }

}
