//  RequestBuilderBodyTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct RequestBuilderBodyTests {

    private let builder = RequestBuilder(multipartBoundary: { "BOUNDARY" })

    @Test("No body sends none, and no content type")
    func noBody() async throws {
        let built = try await build(.none)

        #expect(built.urlRequest.httpBody == nil)
        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(built.notices.isEmpty)
    }

    @Test("A raw body sends its text and its content type")
    func raw() async throws {
        let built = try await build(.raw(content: #"{"name":"é"}"#, contentType: "application/json"))

        #expect(text(of: built) == #"{"name":"é"}"#)
        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("A raw body with no content type sends none")
    func rawWithoutContentType() async throws {
        let built = try await build(.raw(content: "hello", contentType: ""))

        #expect(text(of: built) == "hello")
        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test("A header that sets the content type wins, in any case")
    func manualContentType() async throws {
        let built = try await build(
            .raw(content: "{}", contentType: "application/json"),
            headers: [KeyValue(key: "content-type", value: "application/vnd.moth+json")]
        )

        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/vnd.moth+json")
    }

    @Test("A disabled content type header does not stop the body's own")
    func disabledContentTypeHeader() async throws {
        let built = try await build(
            .raw(content: "{}", contentType: "application/json"),
            headers: [KeyValue(key: "Content-Type", value: "text/plain", isEnabled: false)]
        )

        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("A urlencoded body encodes enabled rows and sets its content type")
    func urlEncoded() async throws {
        let built = try await build(
            .urlEncoded([
                KeyValue(key: "a b", value: "x&y=z+1"),
                KeyValue(key: "draft", value: "true", isEnabled: false),
                KeyValue(key: "name", value: "é")
            ])
        )

        #expect(text(of: built) == "a%20b=x%26y%3Dz%2B1&name=%C3%A9")
        #expect(
            built.urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded"
        )
    }

    @Test("A form-data body sends enabled text fields, each with its own content type")
    func formData() async throws {
        let built = try await build(
            .formData([
                FormDataField(key: "title", value: .text("Hello")),
                FormDataField(key: "draft", value: .text("true"), isEnabled: false),
                FormDataField(key: "meta", value: .text("{}"), contentType: "application/json")
            ])
        )

        let expected = [
            "--BOUNDARY",
            #"Content-Disposition: form-data; name="title""#,
            "",
            "Hello",
            "--BOUNDARY",
            #"Content-Disposition: form-data; name="meta""#,
            "Content-Type: application/json",
            "",
            "{}",
            "--BOUNDARY--",
            ""
        ].joined(separator: "\r\n")
        #expect(text(of: built) == expected)
        #expect(
            built.urlRequest.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=BOUNDARY"
        )
    }

    @Test("A form-data key cannot leave its quoted name, and a content type cannot add a line")
    func formDataEscaping() async throws {
        let built = try await build(
            .formData([
                FormDataField(key: "a\"b\r\nX: y", value: .text("1"), contentType: "text/plain\r\nX: y")
            ])
        )

        let body = try #require(text(of: built))
        #expect(body.contains(#"name="a%22b%0D%0AX: y""#))
        #expect(body.contains("Content-Type: text/plainX: y\r\n"))
    }

    @Test("A form-data file field is left out and reported, and its text fields are still sent")
    func formDataFile() async throws {
        let built = try await build(
            .formData([
                FormDataField(key: "avatar", value: .file(paths: ["/tmp/a.png"])),
                FormDataField(key: "old", value: .file(paths: []), isEnabled: false),
                FormDataField(key: "title", value: .text("Hello"))
            ])
        )

        let body = try #require(text(of: built))
        #expect(body.contains(#"name="title""#))
        #expect(!body.contains("avatar"))
        #expect(built.notices == [.unsupportedFormDataFile(key: "avatar")])
    }

    @Test(
        "A binary or GraphQL body sends no body and is reported",
        arguments: [
            (RequestBody.binary(filePath: "/tmp/a.png"), UnsupportedBodyKind.binary),
            (.binary(filePath: nil), .binary),
            (.graphQL(query: "{ me }", variables: "{}"), .graphQL)
        ]
    )
    func unsupportedBody(body: RequestBody, kind: UnsupportedBodyKind) async throws {
        let built = try await build(body)

        #expect(built.urlRequest.httpBody == nil)
        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(built.notices == [.unsupportedBody(kind)])
    }

    @Test(
        "A body on a method URLSession cannot send it with is left out and reported",
        arguments: [HTTPMethod.get, .head, HTTPMethod(rawValue: "get")]
    )
    func bodyOnBodilessMethod(method: HTTPMethod) async throws {
        let built = try await build(.raw(content: "{}", contentType: "application/json"), method: method)

        #expect(built.urlRequest.httpBody == nil)
        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(built.notices == [.bodyNotSent(method: method)])
    }

    @Test("A form with no row to send stays off a GET without a notice", arguments: [
        [FormDataField](),
        [FormDataField(key: "title", value: .text("Hello"), isEnabled: false)]
    ])
    func emptyFormOnBodilessMethod(fields: [FormDataField]) async throws {
        let built = try await build(.formData(fields), method: .get)

        #expect(built.urlRequest.httpBody == nil)
        #expect(built.notices.isEmpty)
    }

    @Test("A body on DELETE is sent")
    func bodyOnDelete() async throws {
        let built = try await build(.raw(content: "{}", contentType: "application/json"), method: .delete)

        #expect(text(of: built) == "{}")
        #expect(built.notices.isEmpty)
    }

    @Test("A header that hides the form-data boundary keeps its value, and is reported")
    func manualFormDataContentType() async throws {
        let built = try await build(
            .formData([FormDataField(key: "title", value: .text("Hello"))]),
            headers: [KeyValue(key: "Content-Type", value: "multipart/form-data")]
        )

        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data")
        #expect(built.notices == [.formDataBoundaryNotDeclared])
    }

    private func build(
        _ body: RequestBody,
        headers: [KeyValue] = [],
        method: HTTPMethod = .post
    ) async throws -> BuiltRequest {
        try await builder.build(
            ResolvedRequest(method: method, url: "https://example.com", headers: headers, body: body)
        )
    }

    private func text(of built: BuiltRequest) -> String? {
        built.urlRequest.httpBody.flatMap { String(bytes: $0, encoding: .utf8) }
    }

}
