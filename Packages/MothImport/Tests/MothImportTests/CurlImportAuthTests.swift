//  CurlImportAuthTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import MothImport
import Testing

struct CurlImportAuthTests {

    private struct StoreRefusal: Error {}

    private func basic(_ command: String) async throws -> (username: String, password: String?) {
        let store = RecordingSecretStore()
        let request = try await CurlImportTesting.importing(command, secretStore: store).request
        guard case .basic(let auth) = request.auth else {
            Issue.record("Expected Basic Auth, got \(request.auth)")
            return ("", nil)
        }
        return await (auth.username, store.values[auth.password.identifier])
    }

    private func bearerToken(_ command: String) async throws -> String? {
        let store = RecordingSecretStore()
        let request = try await CurlImportTesting.importing(command, secretStore: store).request
        guard case .bearer(let auth) = request.auth else {
            Issue.record("Expected Bearer Token, got \(request.auth)")
            return nil
        }
        return await store.values[auth.token.identifier]
    }

    private nonisolated static func base64(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
    }

    @Test("A command with no credential inherits, as New Request does")
    func noCredentialInherits() async throws {
        #expect(try await CurlImportTesting.request("curl https://a.example").auth == .inherit)
    }

    @Test(
        "-u splits at the first colon",
        arguments: [
            ("curl -u user:password https://a.example", "user", "password"),
            ("curl --user user:pa:ss https://a.example", "user", "pa:ss"),
            ("curl -u user https://a.example", "user", ""),
            ("curl -u :token https://a.example", "", "token"),
            ("curl -u a:b -u c:d https://a.example", "c", "d")
        ]
    )
    func userFlag(text: String, username: String, password: String) async throws {
        let auth = try await basic(text)

        #expect(auth.username == username)
        #expect(auth.password == password)
    }

    @Test("An Authorization: Basic header decodes to a username and a password")
    func basicHeader() async throws {
        let auth = try await basic("curl -H 'Authorization: Basic \(Self.base64("user:pa:ss"))' https://a.example")

        #expect(auth.username == "user")
        #expect(auth.password == "pa:ss")
    }

    @Test(
        "An Authorization: Bearer header becomes a token, whatever the case",
        arguments: ["Authorization: Bearer abc", "authorization: bearer abc", "AUTHORIZATION:   BEARER   abc"]
    )
    func bearerHeader(header: String) async throws {
        #expect(try await bearerToken("curl -H '\(header)' https://a.example") == "abc")
    }

    @Test("A converted Authorization header leaves the rows, and others stay")
    func convertedHeaderLeavesTheRows() async throws {
        let request = try await CurlImportTesting.request(
            "curl -H 'Accept: a' -H 'Authorization: Bearer abc' https://a.example"
        )

        #expect(request.headers.pairs == [Pair("Accept", "a")])
    }

    @Test("A header wins over -u, as a custom header wins in curl")
    func headerWinsOverUser() async throws {
        let store = RecordingSecretStore()
        let result = try await CurlImportTesting.importing(
            "curl -u user:pass -H 'Authorization: Bearer abc' https://a.example",
            secretStore: store
        )

        guard case .bearer = result.request.auth else {
            Issue.record("Expected Bearer Token")
            return
        }
        #expect(await store.values.values.sorted() == ["abc"])
    }

    @Test("A second credential header leaves no secret in a row")
    func secondCredentialHeader() async throws {
        let result = try await CurlImportTesting.importing(
            "curl -H 'Authorization: Bearer t0ken-a' -H 'Authorization: Bearer t0ken-b' https://a.example"
        )

        #expect(result.request.headers.isEmpty)
        #expect(!String(reflecting: result.request).contains("t0ken-b"))
    }

    @Test(
        "A header Moth can't convert stays a header",
        arguments: ["Authorization: Token abc", "Authorization: Basic !!!", "Authorization: Basic YWJj"]
    )
    func otherSchemesStayHeaders(header: String) async throws {
        let request = try await CurlImportTesting.request("curl -H '\(header)' https://a.example")

        #expect(request.auth == .inherit)
        #expect(request.headers.count == 1)
    }

    @Test("A URL's user and password leave the template and become Basic Auth")
    func urlUserinfo() async throws {
        let store = RecordingSecretStore()
        let request = try await CurlImportTesting.importing(
            "curl https://us%20er:pa%3Ass@a.example/x",
            secretStore: store
        ).request

        #expect(request.urlTemplate == "https://a.example/x")
        guard case .basic(let auth) = request.auth else {
            Issue.record("Expected Basic Auth")
            return
        }
        #expect(auth.username == "us er")
        #expect(await store.values[auth.password.identifier] == "pa:ss")
    }

    @Test("-u wins over a URL's user, and the URL's password still leaves the template")
    func userWinsOverURL() async throws {
        let store = RecordingSecretStore()
        let request = try await CurlImportTesting.importing(
            "curl -u flag:one https://url:two@a.example/x",
            secretStore: store
        ).request

        #expect(request.urlTemplate == "https://a.example/x")
        #expect(await store.values.values.sorted() == ["one"])
    }

    @Test(
        "Credentials reach the secret store and not the request",
        arguments: [
            "curl -u user:s3cret https://a.example",
            "curl -H 'Authorization: Bearer s3cret' https://a.example",
            "curl -H 'Authorization: Basic \(base64("user:s3cret"))' https://a.example",
            "curl https://user:s3cret@a.example"
        ]
    )
    func credentialsStayOutOfTheRequest(text: String) async throws {
        let store = RecordingSecretStore()
        let result = try await CurlImportTesting.importing(text, secretStore: store)

        #expect(await store.values.values.contains("s3cret"))
        #expect(!String(reflecting: result.request).contains("s3cret"))
        #expect(await Set(store.values.keys) == Set(result.secrets.map(\.identifier)))
    }

    @Test("A failed save rethrows and leaves no secret")
    func failedSave() async {
        let store = RecordingSecretStore(refusing: "pass")

        await #expect(throws: RecordingSecretStore.Failure.refused) {
            try await CurlImportTesting.importing("curl -u user:pass https://a.example", secretStore: store)
        }
        #expect(await store.values.isEmpty)
    }

    @Test("A failed store write removes the secrets and rethrows")
    func failedStoreWrite() async {
        let store = RecordingSecretStore()
        let importer = CurlImporter(secretStore: store)

        await #expect(throws: StoreRefusal.self) {
            try await importer.importCommand("curl -u user:pass https://a.example") { _ in
                throw StoreRefusal()
            }
        }
        #expect(await store.values.isEmpty)
    }

    @Test("The store receives the request the result holds")
    func storeReceivesTheRequest() async throws {
        let received = RecordedRequest()

        let result = try await CurlImporter(secretStore: RecordingSecretStore())
            .importCommand("curl https://a.example") { await received.keep($0) }

        #expect(await received.request == result.request)
    }

}

private actor RecordedRequest {

    private(set) var request: Request?

    func keep(_ request: Request) {
        self.request = request
    }

}
