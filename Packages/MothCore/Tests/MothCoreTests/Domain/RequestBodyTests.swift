//  RequestBodyTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct RequestBodyTests {

    @Test("No body differs from an empty raw body")
    func noneIsNotAnEmptyRawBody() {
        #expect(RequestBody.none != .raw(content: "", contentType: ""))
    }

    @Test("Form-data keeps its text and file rows in order")
    func formDataKeepsItsRows() throws {
        let text = FormDataField(key: "note", value: .text("hello"))
        let file = FormDataField(
            key: "upload",
            value: .file(paths: ["/tmp/a.png", "/tmp/b.png"]),
            contentType: "image/png"
        )

        guard case .formData(let fields) = RequestBody.formData([text, file]) else {
            Issue.record("Expected a form-data body")
            return
        }

        #expect(fields == [text, file])
        #expect(try #require(fields.first).value == .text("hello"))
        #expect(try #require(fields.last).value == .file(paths: ["/tmp/a.png", "/tmp/b.png"]))
        #expect(try #require(fields.last).contentType == "image/png")
    }

    @Test("A new form-data row is enabled with no content type of its own")
    func newFormDataRowDefaults() {
        let field = FormDataField(key: "note", value: .text("hello"))

        #expect(field.isEnabled)
        #expect(field.contentType == nil)
    }

    @Test("A disabled form-data row stays disabled")
    func disabledFormDataRowStaysDisabled() {
        let field = FormDataField(key: "note", value: .text("hello"), isEnabled: false)

        #expect(!field.isEnabled)
    }

    @Test("URL-encoded keeps its rows, including disabled ones")
    func urlEncodedKeepsItsRows() {
        let rows = [KeyValue(key: "a", value: "1"), KeyValue(key: "b", value: "2", isEnabled: false)]

        guard case .urlEncoded(let kept) = RequestBody.urlEncoded(rows) else {
            Issue.record("Expected a URL-encoded body")
            return
        }

        #expect(kept == rows)
    }

    @Test("Raw keeps its content and content type")
    func rawKeepsItsContentAndType() {
        guard case .raw(let content, let contentType) = RequestBody.raw(
            content: "{}",
            contentType: "application/json"
        ) else {
            Issue.record("Expected a raw body")
            return
        }

        #expect(content == "{}")
        #expect(contentType == "application/json")
    }

    @Test("Binary keeps its file path")
    func binaryKeepsItsFilePath() {
        guard case .binary(let filePath) = RequestBody.binary(filePath: "/tmp/photo.jpg") else {
            Issue.record("Expected a binary body")
            return
        }

        #expect(filePath == "/tmp/photo.jpg")
    }

    @Test("Binary can have no file chosen yet")
    func binaryCanHaveNoFile() {
        guard case .binary(let filePath) = RequestBody.binary(filePath: nil) else {
            Issue.record("Expected a binary body")
            return
        }

        #expect(filePath == nil)
    }

    @Test("GraphQL keeps its query and variables")
    func graphQLKeepsItsQueryAndVariables() {
        guard case .graphQL(let query, let variables) = RequestBody.graphQL(
            query: "{ me { id } }",
            variables: "{\"a\":1}"
        ) else {
            Issue.record("Expected a GraphQL body")
            return
        }

        #expect(query == "{ me { id } }")
        #expect(variables == "{\"a\":1}")
    }

}
