//  PostmanAWSSignatureTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import MothImport
import Testing

struct PostmanAWSSignatureTests {

    private static let export =
        "aws-iam-identity-center-extensions/aws-sso-extensions-for-enterprise.postman_collection.json"

    private func auth(of request: Request?) throws -> AWSSigV4Auth {
        guard case .awsSigV4(let sigV4) = request?.auth else {
            throw PostmanAWSSignatureError.notAWSSignature
        }
        return sigV4
    }

    private static func variable(_ name: String, _ value: String) -> Variable {
        Variable(name: name, value: .plain(initial: value, current: value))
    }

    @Test("A real export counts nothing as unsupported, and takes Postman's service for the one it left out")
    func realExportMaps() async throws {
        let result = try await Fixture.importing(Self.export)

        let requests = try #require(result.collection?.requests)
        #expect(requests.count == 24)
        #expect(result.imported.unsupportedAuth.isEmpty)
        for request in requests {
            let sigV4 = try auth(of: request)
            #expect(sigV4.region == "{{region}}")
            #expect(sigV4.service == "execute-api")
        }
    }

    @Test("A real export's credentials reach the secret store")
    func realExportStoresCredentials() async throws {
        let store = InMemorySecretStore()
        let result = try await Fixture.importing(Self.export, secretStore: store)

        let sigV4 = try auth(of: result.collection?.requests.first)

        #expect(await Fixture.stored(sigV4.accessKeyID, in: store) == "{{links-accessKey}}")
        #expect(await Fixture.stored(sigV4.secretAccessKey, in: store) == "{{links-secretAccessKey}}")
        #expect(await Fixture.stored(sigV4.sessionToken, in: store) == "{{links-sessionToken}}")
    }

    @Test("A real export signs with no further edit")
    func realExportSigns() async throws {
        let store = InMemorySecretStore()
        let result = try await Fixture.importing(Self.export, secretStore: store)
        let request = try #require(result.collection?.requests.first)
        let date = Date(timeIntervalSince1970: 1_440_938_160)

        let resolved = try await VariableResolver(secretStore: store).resolve(
            request,
            collection: [],
            environment: [
                Self.variable("linksEndpoint", "https://abc.execute-api.eu-west-1.amazonaws.com/"),
                Self.variable("region", "eu-west-1"),
                Self.variable("links-accessKey", "AKIDEXAMPLE"),
                Self.variable("links-secretAccessKey", "secret"),
                Self.variable("links-sessionToken", "token")
            ],
            globals: []
        )
        let built = try await RequestBuilder(now: { date }).build(resolved)

        let authorization = try #require(built.urlRequest.value(forHTTPHeaderField: "Authorization"))
        #expect(authorization.hasPrefix(
            "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/eu-west-1/execute-api/aws4_request, "
        ))
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Amz-Security-Token") == "token")
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Amz-Date") == "20150830T123600Z")
    }

    @Test(
        "Fields Postman defaults take its defaults, from a snippet because no licensed fixture leaves out a region",
        arguments: [
            #"[]"#,
            #"[{ "key": "region", "value": "" }, { "key": "service", "value": "" }]"#
        ]
    )
    func postmanDefaults(parameters: String) async throws {
        let result = try await Fixture.importingAuth(#"{ "type": "awsv4", "awsv4": \#(parameters) }"#)

        let sigV4 = try auth(of: result.collection?.requests.first)

        #expect(sigV4.region == "us-east-1")
        #expect(sigV4.service == "execute-api")
    }

    @Test("An empty session token has no reference, from a snippet because the export's isn't empty")
    func emptySessionToken() async throws {
        let result = try await Fixture.importingAuth(#"""
        { "type": "awsv4", "awsv4": [{ "key": "sessionToken", "value": "" }] }
        """#)

        #expect(try auth(of: result.collection?.requests.first).sessionToken == nil)
    }

}

private nonisolated enum PostmanAWSSignatureError: Error {

    case notAWSSignature

}
