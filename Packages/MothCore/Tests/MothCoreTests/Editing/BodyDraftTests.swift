//  BodyDraftTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct BodyDraftTests {

    private nonisolated static let bodies: [RequestBody] = [
        .none,
        .raw(content: "{}", contentType: "application/json"),
        .raw(content: "x", contentType: "application/javascript"),
        .urlEncoded([KeyValue(key: "a", value: "b", isEnabled: false)]),
        .formData([
            FormDataField(key: "name", value: .text("Ada"), contentType: "text/plain"),
            FormDataField(key: "photo", value: .file(paths: ["/tmp/a.png", "/tmp/b.png"]), isEnabled: false)
        ]),
        .binary(filePath: "/tmp/a.bin"),
        .graphQL(query: "{ me }", variables: "{}")
    ]

    @Test("Each body comes back unchanged from a draft nobody edited", arguments: bodies)
    func roundTrips(body: RequestBody) {
        #expect(BodyDraft(body).requestBody == body)
    }

    @Test("A new raw body is JSON with no text")
    func newRawBody() {
        var draft = BodyDraft(.none)

        draft.kind = .raw

        #expect(draft.requestBody == .raw(content: "", contentType: "application/json"))
    }

    @Test("The four raw types use the media types an import stores")
    func rawContentTypes() {
        #expect(RawContentType.allCases.map(\.rawValue) == [
            "application/json", "text/plain", "application/xml", "text/html"
        ])
    }

    @Test("Trying another kind keeps the fields, and only the chosen kind is saved")
    func switchingKeepsFields() {
        var draft = BodyDraft(.raw(content: "{}", contentType: "application/json"))

        draft.kind = .urlEncoded
        draft.urlEncodedRows.append(KeyValue(key: "a", value: "b"))
        #expect(draft.requestBody == .urlEncoded(draft.urlEncodedRows))

        draft.kind = .raw
        #expect(draft.requestBody == .raw(content: "{}", contentType: "application/json"))
    }

    @Test("Choosing another kind and back keeps a body the editor can't change", arguments: [
        RequestBody.binary(filePath: "/tmp/a.bin"),
        .graphQL(query: "{ me }", variables: "{}")
    ])
    func unsupportedBodySurvivesASwitch(body: RequestBody) {
        var draft = BodyDraft(body)
        let kept = draft.kind

        draft.kind = .raw
        draft.kind = kept

        #expect(draft.requestBody == body)
    }

    @Test("The kinds are the four editable ones, plus a stored kind the editor can't change")
    func kinds() {
        #expect(BodyDraft(.none).kinds == [.none, .formData, .urlEncoded, .raw])
        #expect(BodyDraft(.binary(filePath: nil)).kinds == [.none, .formData, .urlEncoded, .raw, .binary])
        #expect(
            BodyDraft(.graphQL(query: "", variables: "")).kinds == [.none, .formData, .urlEncoded, .raw, .graphQL]
        )
    }

    @Test("Editing the text rows of a form keeps its file rows")
    func editingKeepsFileRows() {
        let file = FormDataField(key: "photo", value: .file(paths: ["/tmp/a.png"]))
        var draft = BodyDraft(.formData([FormDataField(key: "name", value: .text("Ada")), file]))

        draft.formDataFields[0].value = .text("Grace")
        draft.formDataFields.append(FormDataField(key: "age", value: .text("36")))

        guard case .formData(let fields) = draft.requestBody else {
            Issue.record("The draft should still be form-data")
            return
        }
        #expect(fields.map(\.key) == ["name", "photo", "age"])
        #expect(fields[1] == file)
    }

    @Test("Rows typed back in are the same content, whatever their identifiers")
    func comparisonIgnoresRowIdentifiers() {
        let urlEncoded = BodyDraft(.urlEncoded([KeyValue(key: "a", value: "b")]))
        let form = BodyDraft(.formData([FormDataField(key: "a", value: .text("b"), contentType: "text/plain")]))

        #expect(urlEncoded.hasSameContent(as: BodyDraft(.urlEncoded([KeyValue(key: "a", value: "b")]))))
        #expect(form.hasSameContent(
            as: BodyDraft(.formData([FormDataField(key: "a", value: .text("b"), contentType: "text/plain")]))
        ))
        #expect(BodyDraft(.none).hasSameContent(as: BodyDraft(.none)))
    }

    @Test("A different kind, row or field is different content", arguments: [
        (RequestBody.none, RequestBody.urlEncoded([])),
        (.urlEncoded([]), .formData([])),
        (.raw(content: "a", contentType: "text/plain"), .raw(content: "b", contentType: "text/plain")),
        (.raw(content: "a", contentType: "text/plain"), .raw(content: "a", contentType: "text/html")),
        (
            .urlEncoded([KeyValue(key: "a", value: "b")]),
            .urlEncoded([KeyValue(key: "a", value: "b", isEnabled: false)])
        ),
        (
            .formData([FormDataField(key: "a", value: .text("b"))]),
            .formData([FormDataField(key: "a", value: .text("b"), contentType: "text/plain")])
        ),
        (.binary(filePath: "/a"), .binary(filePath: "/b"))
    ])
    func comparisonSeesContent(first: RequestBody, second: RequestBody) {
        #expect(!BodyDraft(first).hasSameContent(as: BodyDraft(second)))
    }

}
