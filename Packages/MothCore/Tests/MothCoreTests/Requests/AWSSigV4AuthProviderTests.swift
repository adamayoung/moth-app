//  AWSSigV4AuthProviderTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CryptoKit
import Foundation
import MothCore
import Testing

struct AWSSigV4AuthProviderTests {

    private static let suiteDate = Date(timeIntervalSince1970: 1_440_938_160)
    private static let vanillaSignature = "5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31"

    private func provider(
        accessKey: String = "AKIDEXAMPLE",
        secretKey: String = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
        sessionToken: String? = nil,
        region: String = "us-east-1",
        service: String = "service",
        date: Date = suiteDate
    ) -> AWSSigV4AuthProvider {
        AWSSigV4AuthProvider(
            accessKey: accessKey,
            secretKey: secretKey,
            sessionToken: sessionToken,
            region: region,
            service: service,
            date: date
        )
    }

    private func signed(
        _ address: String = "https://example.amazonaws.com/",
        by provider: AWSSigV4AuthProvider? = nil,
        configure: (inout URLRequest) -> Void = { _ in }
    ) async throws -> URLRequest {
        var request = try URLRequest(url: #require(URL(string: address)))
        configure(&request)
        try await (provider ?? self.provider()).apply(to: &request)
        return request
    }

    private func signature(of request: URLRequest) throws -> String {
        let authorization = try #require(request.value(forHTTPHeaderField: "Authorization"))
        return try String(#require(authorization.split(separator: "Signature=").last))
    }

    private func signedHeaders(of request: URLRequest) throws -> [Substring] {
        let authorization = try #require(request.value(forHTTPHeaderField: "Authorization"))
        let match = try #require(authorization.firstMatch(of: /SignedHeaders=([^,]*),/))
        return match.output.1.split(separator: ";")
    }

    @Test("A signed request carries the Authorization header and date AWS's suite shows")
    func authorizationForm() async throws {
        let request = try await signed()

        #expect(request.value(forHTTPHeaderField: "X-Amz-Date") == "20150830T123600Z")
        #expect(request.value(forHTTPHeaderField: "Authorization") == """
        AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/service/aws4_request, \
        SignedHeaders=host;x-amz-date, Signature=\(Self.vanillaSignature)
        """)
    }

    @Test("A session token is sent, and signed")
    func sessionToken() async throws {
        let token = "6e86291e8372ff2a2260956d9b8aae1d763fbf315fa00fa31553b73ebf194267"

        let request = try await signed(by: provider(sessionToken: token))

        #expect(request.value(forHTTPHeaderField: "X-Amz-Security-Token") == token)
        #expect(try signedHeaders(of: request) == ["host", "x-amz-date", "x-amz-security-token"])
        #expect(try signature(of: request) == "07ec1639c89043aa0e3e2de82b96708f198cceab042d4a97044c66dd9f74e7f8")
    }

    @Test("No session token sends no token header", arguments: [nil, ""])
    func noSessionToken(token: String?) async throws {
        let request = try await signed(by: provider(sessionToken: token))

        #expect(request.value(forHTTPHeaderField: "X-Amz-Security-Token") == nil)
        #expect(try signature(of: request) == Self.vanillaSignature)
    }

    @Test("Only s3 carries X-Amz-Content-Sha256")
    func contentHashIsS3Only() async throws {
        let plain = try await signed()
        let bucket = try await signed(by: provider(service: "s3"))

        #expect(plain.value(forHTTPHeaderField: "X-Amz-Content-Sha256") == nil)
        #expect(bucket.value(forHTTPHeaderField: "X-Amz-Content-Sha256") == Self.emptyPayloadHash)
    }

    @Test("Headers the signature sets replace manual rows, in any case")
    func manualRowsAreReplaced() async throws {
        let request = try await signed { request in
            request.setValue("manual", forHTTPHeaderField: "authorization")
            request.setValue("manual", forHTTPHeaderField: "x-amz-date")
        }

        #expect(request.value(forHTTPHeaderField: "X-Amz-Date") == "20150830T123600Z")
        #expect(try signature(of: request) == Self.vanillaSignature)
    }

    @Test("Headers URLSession can rewrite aren't signed", arguments: ["Content-Length", "Connection"])
    func reservedHeadersAreLeftOut(name: String) async throws {
        let request = try await signed { $0.setValue("1", forHTTPHeaderField: name) }

        #expect(try signature(of: request) == Self.vanillaSignature)
    }

    @Test("A header row is signed")
    func headersAreSigned() async throws {
        let request = try await signed { $0.setValue("1", forHTTPHeaderField: "X-Custom") }

        #expect(try signedHeaders(of: request) == ["host", "x-amz-date", "x-custom"])
        #expect(try signature(of: request) != Self.vanillaSignature)
    }

    @Test("A default port is left out of the signed host")
    func defaultPort() async throws {
        let request = try await signed("https://example.amazonaws.com:443/")

        #expect(try signature(of: request) == Self.vanillaSignature)
    }

    @Test("Another port is part of the signed host")
    func otherPort() async throws {
        let withPort = try await signed("https://example.amazonaws.com:8443/")
        let matchingHostHeader = try await signed { request in
            request.setValue("example.amazonaws.com:8443", forHTTPHeaderField: "Host")
        }

        #expect(try signature(of: withPort) == signature(of: matchingHostHeader))
        #expect(try signature(of: withPort) != Self.vanillaSignature)
    }

    @Test("The signed host is the lowercase one URLSession sends")
    func hostCase() async throws {
        let request = try await signed("https://EXAMPLE.amazonaws.com/")

        #expect(try signature(of: request) == Self.vanillaSignature)
    }

    @Test("An international host signs in the form URLSession sends")
    func internationalHost() async throws {
        let unicode = try await signed("https://bücher.example/")
        let encoded = try await signed("https://xn--bcher-kva.example/")

        #expect(try signature(of: unicode) == signature(of: encoded))
    }

    @Test("A literal + in a query signs as the space a server reads")
    func plusInQuery() async throws {
        let plus = try await signed("https://example.amazonaws.com/?a=b+c")
        let space = try await signed("https://example.amazonaws.com/?a=b%20c")

        #expect(try signature(of: plus) == signature(of: space))
    }

    @Test("Any bytes in a body hash as they are")
    func binaryBytes() async throws {
        let bytes = Data([0xFF, 0x00, 0xFE, 0x80])
        let plain = try await signed(by: provider(service: "s3"))

        let request = try await signed(by: provider(service: "s3")) { $0.httpBody = bytes }

        #expect(request.value(forHTTPHeaderField: "X-Amz-Content-Sha256") == Self.hash(bytes))
        #expect(try signature(of: request) != signature(of: plain))
    }

    @Test(
        "An empty field stops the build",
        arguments: [
            (accessKey: "", secretKey: "s", region: "r", service: "a"),
            (accessKey: "k", secretKey: "", region: "r", service: "a"),
            (accessKey: "k", secretKey: "s", region: "", service: "a"),
            (accessKey: "k", secretKey: "s", region: "r", service: "")
        ]
    )
    func emptyField(fields: (accessKey: String, secretKey: String, region: String, service: String)) async throws {
        let incomplete = provider(
            accessKey: fields.accessKey,
            secretKey: fields.secretKey,
            region: fields.region,
            service: fields.service
        )

        await #expect(throws: RequestBuildError.incompleteAWSSignature) {
            _ = try await signed(by: incomplete)
        }
    }

    @Test("The missing field error names all four")
    func missingFieldMessage() {
        #expect(
            RequestBuildError.incompleteAWSSignature.errorDescription
                == "AWS Signature needs an access key, secret key, region and service."
        )
    }

    @Test(
        "A field that can't go in a header stops the build",
        arguments: [
            (accessKey: "a\nb", sessionToken: "t", region: "r", service: "s"),
            (accessKey: "a", sessionToken: "t\nu", region: "r", service: "s"),
            (accessKey: "a", sessionToken: "t", region: "r\nu", service: "s"),
            (accessKey: "a", sessionToken: "t", region: "r", service: "s\nu")
        ]
    )
    func unsendableField(fields: (accessKey: String, sessionToken: String, region: String, service: String)) async {
        let unsendable = provider(
            accessKey: fields.accessKey,
            sessionToken: fields.sessionToken,
            region: fields.region,
            service: fields.service
        )

        await #expect(throws: RequestBuildError.unsendableAWSSignature) {
            _ = try await signed(by: unsendable)
        }
    }

    // AWS's worked examples for S3, from "Examples: Signature Calculations" in the Amazon S3 API Reference.
    private static let s3Date = Date(timeIntervalSince1970: 1_369_353_600)
    private static let s3AccessKey = "AKIAIOSFODNN7EXAMPLE"
    private static let s3SecretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    private static let emptyPayloadHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    private var s3Provider: AWSSigV4AuthProvider {
        provider(
            accessKey: Self.s3AccessKey,
            secretKey: Self.s3SecretKey,
            service: "s3",
            date: Self.s3Date
        )
    }

    @Test("S3's GET object example signs as AWS publishes")
    func s3GetObject() async throws {
        let request = try await signed("https://examplebucket.s3.amazonaws.com/test.txt", by: s3Provider) { request in
            request.setValue("bytes=0-9", forHTTPHeaderField: "Range")
        }

        #expect(try signedHeaders(of: request) == ["host", "range", "x-amz-content-sha256", "x-amz-date"])
        #expect(try signature(of: request) == "f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41")
    }

    @Test("S3's PUT object example signs as AWS publishes, with its key encoded once")
    func s3PutObject() async throws {
        let body = Data("Welcome to Amazon S3.".utf8)

        let request = try await signed("https://examplebucket.s3.amazonaws.com/test$file.text", by: s3Provider) {
            $0.httpMethod = "PUT"
            $0.httpBody = body
            $0.setValue("Fri, 24 May 2013 00:00:00 GMT", forHTTPHeaderField: "Date")
            $0.setValue("REDUCED_REDUNDANCY", forHTTPHeaderField: "x-amz-storage-class")
        }

        #expect(request.value(forHTTPHeaderField: "X-Amz-Content-Sha256") == Self.hash(body))
        #expect(try signature(of: request) == "98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd")
    }

    @Test("S3's GET bucket lifecycle example signs as AWS publishes")
    func s3Lifecycle() async throws {
        let request = try await signed("https://examplebucket.s3.amazonaws.com/?lifecycle", by: s3Provider)

        #expect(try signature(of: request) == "fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543")
    }

    @Test("S3's list objects example signs as AWS publishes")
    func s3ListObjects() async throws {
        let request = try await signed("https://examplebucket.s3.amazonaws.com/?max-keys=2&prefix=J", by: s3Provider)

        #expect(try signature(of: request) == "34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7")
    }

    @Test("S3 keeps a path's slashes and dots, because they are part of the key")
    func s3PathIsLiteral() async throws {
        let dotted = try await signed("https://b.s3.amazonaws.com/a//b/../c", by: s3Provider)
        let plain = try await signed("https://b.s3.amazonaws.com/a/c", by: s3Provider)

        #expect(try signature(of: dotted) != signature(of: plain))
    }

    @Test("Another service encodes a wire path a second time")
    func otherServicesEncodeTwice() async throws {
        let encoded = try await signed("https://example.amazonaws.com/a%20b")
        let doubled = try await signed("https://example.amazonaws.com/a%2520b")

        #expect(try signature(of: encoded) != signature(of: doubled))
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

}
