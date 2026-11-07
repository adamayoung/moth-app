//  AWSSigV4SignerVectorTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import Testing

struct AWSSigV4SignerVectorTests {

    @Test("Every vector AWS publishes that Moth can send is exercised")
    func vectorsAreFound() {
        #expect(AWSSigV4Vector.applicable.count == 29)
    }

    @Test("The canonical request matches AWS's published suite", arguments: AWSSigV4Vector.applicable)
    func canonicalRequest(vector: AWSSigV4Vector) throws {
        #expect(try vector.signer().canonicalRequest == vector.expected("header-canonical-request.txt"))
    }

    @Test("The string to sign matches AWS's published suite", arguments: AWSSigV4Vector.applicable)
    func stringToSign(vector: AWSSigV4Vector) throws {
        #expect(try vector.signer().stringToSign == vector.expected("header-string-to-sign.txt"))
    }

    @Test("The signature matches AWS's published suite", arguments: AWSSigV4Vector.applicable)
    func signature(vector: AWSSigV4Vector) throws {
        #expect(try vector.signer().signature == vector.expected("header-signature.txt"))
    }

}

/// Each folder is an unchanged copy of one case in AWS's suite. Its request line carries the path the signer reads, so
/// `/example space/` stands for a path already encoded once on the wire, and a `URL` couldn't hold it.
nonisolated struct AWSSigV4Vector: Sendable, CustomTestStringConvertible {

    private struct ContextCredentials: Decodable {

        let accessKeyID: String
        let secretAccessKey: String
        let token: String?

        private enum CodingKeys: String, CodingKey {

            case accessKeyID = "access_key_id"
            case secretAccessKey = "secret_access_key"
            case token

        }

    }

    private struct Context: Decodable {

        let credentials: ContextCredentials
        let normalize: Bool
        let region: String
        let service: String
        let timestamp: Date
        let omitSessionToken: Bool?
        let signBody: Bool

        private enum CodingKeys: String, CodingKey {

            case credentials, normalize, region, service, timestamp
            case omitSessionToken = "omit_session_token"
            case signBody = "sign_body"

        }

    }

    private static var suite: URL {
        (Bundle.module.resourceURL ?? Bundle.module.bundleURL).appending(path: "Fixtures/aws-signing-test-suite")
    }

    /// Left out: Moth has no unnormalized mode, `post-sts-header-after` leaves the token out of the signature and the
    /// issue signs it, and a header row can't hold a line break.
    static let applicable: [AWSSigV4Vector] = {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: suite.path())) ?? []

        return names.sorted().filter { $0 != "get-header-value-multiline" }.compactMap { name in
            guard
                let context = try? context(named: name),
                context.normalize,
                context.omitSessionToken != true
            else {
                return nil
            }
            return AWSSigV4Vector(name: name)
        }
    }()

    let name: String

    var testDescription: String {
        name
    }

    func expected(_ file: String) throws -> String {
        try String(contentsOf: Self.suite.appending(path: "\(name)/\(file)"), encoding: .utf8)
    }

    func signer() throws -> AWSSigV4Signer {
        let context = try Self.context(named: name)
        let request = try ParsedRequest(expected("request.txt"))
        let date = context.timestamp.formatted(.awsSigV4Timestamp)
        var headers = request.headers
        headers["X-Amz-Date"] = date

        if let token = context.credentials.token {
            headers["X-Amz-Security-Token"] = token
        }

        if context.signBody {
            headers["X-Amz-Content-Sha256"] = AWSSigV4Signer.hash(request.body)
        }

        return AWSSigV4Signer(
            method: request.method,
            path: request.path,
            query: request.query,
            headers: headers,
            payloadHash: AWSSigV4Signer.hash(request.body),
            date: context.timestamp,
            credentials: AWSSigV4Signer.Credentials(
                accessKey: context.credentials.accessKeyID,
                secretKey: context.credentials.secretAccessKey,
                region: context.region,
                service: context.service
            )
        )
    }

    private static func context(named name: String) throws -> Context {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Context.self, from: Data(contentsOf: suite.appending(path: "\(name)/context.json")))
    }

}

/// The suite's raw HTTP. A repeated header joins with a comma in order, as `URLRequest.addValue` joins it.
private nonisolated struct ParsedRequest {

    let method: String
    let path: String
    let query: String?
    let headers: [String: String]
    let body: Data

    init(_ text: String) throws {
        let parts = text.split(separator: "\n\n", maxSplits: 1, omittingEmptySubsequences: false)
        let lines = parts[0].split(separator: "\n")
        let requestLine = try #require(lines.first)
        let target = requestLine.dropFirst(requestLine.prefix { $0 != " " }.count + 1).dropLast(" HTTP/1.1".count)
        let address = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)

        self.method = String(requestLine.prefix { $0 != " " })
        self.path = String(address[0])
        self.query = address.count > 1 ? String(address[1]) : nil
        self.body = Data((parts.count > 1 ? parts[1] : "").utf8)

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let colon = try #require(line.firstIndex(of: ":"))
            let name = String(line[..<colon])
            let value = String(line[line.index(after: colon)...])
            headers[name] = headers[name].map { "\($0),\(value)" } ?? value
        }
        self.headers = headers
    }

}
