//  RequestSenderLeftOutVariableTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Testing

struct RequestSenderLeftOutVariableTests {

    private func sentNotes(_ request: Request) async -> [ResponseNote] {
        let sender = RequestSender(transport: RecordingTransport(), secretStore: InMemorySecretStore())
        let result = await sender.send(OutgoingRequest(request: request), scopes: VariableScopes())

        guard case .response(let response) = result else {
            Issue.record("Expected a response, got \(result)")
            return []
        }
        return response.notes
    }

    @Test("A variable only in a body left off a GET has no note of its own")
    func variableInLeftOutBody() async {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            body: .raw(content: "{{x}}", contentType: "text/plain")
        )

        #expect(await sentNotes(request) == [.bodyNotSent(.get)])
    }

    @Test("A variable only in a left-out body shows just the body's note", arguments: [
        (HTTPMethod.head, RequestBody.raw(content: "{{x}}", contentType: ""), ResponseNote.bodyNotSent(.head)),
        (.post, .graphQL(query: "{{x}}", variables: ""), .unsupportedBody),
        (.get, .urlEncoded([KeyValue(key: "a", value: "{{x}}")]), .bodyNotSent(.get)),
        (.get, .formData([FormDataField(key: "a", value: .text("{{x}}"))]), .bodyNotSent(.get)),
        (.get, .raw(content: "body", contentType: "{{x}}"), .bodyNotSent(.get))
    ])
    func variableInLeftOutBodyOfEachKind(method: HTTPMethod, body: RequestBody, note: ResponseNote) async {
        let request = Request(name: "List", method: method, urlTemplate: "https://example.com", body: body)

        #expect(await sentNotes(request) == [note])
    }

    @Test("A variable only in a left-out header shows just the header's note", arguments: [
        (KeyValue(key: "{{x}}", value: "1"), ResponseNote.unsendableHeader("{{x}}")),
        (KeyValue(key: "X Trace", value: "{{x}}"), .unsendableHeader("X Trace"))
    ])
    func variableInLeftOutHeader(header: KeyValue, note: ResponseNote) async {
        let request = Request(name: "List", urlTemplate: "https://example.com", headers: [header])

        #expect(await sentNotes(request) == [note])
    }

    @Test("A variable only in a left-out file row shows just the file's note")
    func variableInLeftOutFile() async {
        let file = FormDataField(key: "{{x}}", value: .file(paths: ["/tmp/photo.png"]), contentType: "{{y}}")
        let request = Request(
            name: "Upload",
            method: .post,
            urlTemplate: "https://example.com",
            body: .formData([file])
        )

        #expect(await sentNotes(request) == [.unsupportedFile("{{x}}")])
    }

    @Test("A variable only in auth that wasn't sent shows just the auth's note", arguments: [
        (
            Auth.digest(DigestAuth(username: "{{x}}", password: SecretReference(identifier: "no-value"))),
            ResponseNote.unsupportedAuth
        ),
        (.basic(BasicAuth(username: "{{x}}", password: SecretReference(identifier: "no-value"))), .missingCredential)
    ])
    func variableInLeftOutAuth(auth: Auth, note: ResponseNote) async {
        let request = Request(name: "List", urlTemplate: "https://example.com", auth: auth)

        #expect(await sentNotes(request) == [note])
    }

    @Test("A variable only in a row with a blank key has no note")
    func variableInBlankRows() async {
        let blank = KeyValue(key: "", value: "{{a}}")
        let request = Request(
            name: "Upload",
            method: .post,
            urlTemplate: "https://example.com",
            queryParameters: [KeyValue(key: "", value: "{{b}}")],
            headers: [blank],
            body: .formData([FormDataField(key: "", value: .text("{{c}}"))])
        )

        #expect(await sentNotes(request).isEmpty)
    }

    @Test("A variable only in a blank URL-encoded row has no note")
    func variableInBlankEncodedRow() async {
        let request = Request(
            name: "Upload",
            method: .post,
            urlTemplate: "https://example.com",
            body: .urlEncoded([KeyValue(key: "", value: "{{x}}")])
        )

        #expect(await sentNotes(request).isEmpty)
    }

    @Test("A variable only in a path variable the URL doesn't use has no note")
    func variableInUnusedPathVariable() async {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com/users",
            pathParameters: [KeyValue(key: "id", value: "{{x}}")]
        )

        #expect(await sentNotes(request).isEmpty)
    }

    @Test("A variable in a sent part and a left-out part keeps its note")
    func variableAlsoSent() async {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "X-Token", value: "{{x}}")],
            body: .raw(content: "{{x}}", contentType: "")
        )

        #expect(await sentNotes(request) == [.undefinedVariable("x"), .bodyNotSent(.get)])
    }

    @Test("The one variable left after the left-out ones reads by name")
    func oneSentAmongLeftOut() async {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "X-Token", value: "{{c}}")],
            body: .raw(content: "{{a}}{{b}}", contentType: "")
        )

        #expect(await sentNotes(request) == [.undefinedVariable("c"), .bodyNotSent(.get)])
    }

    @Test("The count note counts only variables that went out")
    func countsOnlySent() async {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "X-Token", value: "{{a}}{{b}}{{c}}")],
            body: .raw(content: "{{d}}", contentType: "")
        )

        #expect(await sentNotes(request) == [.undefinedVariables(3), .bodyNotSent(.get)])
    }

}
