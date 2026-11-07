//  RequestSenderEmptyNameTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Testing

struct RequestSenderEmptyNameTests {

    private let scopes = VariableScopes(environment: [
        Variable(name: "x", value: .plain(initial: "", current: "")),
        Variable(name: "y", value: .plain(initial: "", current: ""))
    ])

    private func sentNotes(_ request: Request) async -> [ResponseNote] {
        let sender = RequestSender(transport: RecordingTransport(), secretStore: InMemorySecretStore())
        let result = await sender.send(OutgoingRequest(request: request), scopes: scopes)

        guard case .response(let response) = result else {
            Issue.record("Expected a response, got \(result)")
            return []
        }
        return response.notes
    }

    private func post(_ body: RequestBody) -> Request {
        Request(name: "Upload", method: .post, urlTemplate: "https://example.com", body: body)
    }

    private func get(_ body: RequestBody) -> Request {
        Request(name: "List", urlTemplate: "https://example.com", body: body)
    }

    private func field(_ key: String, _ value: String = "1") -> FormDataField {
        FormDataField(key: key, value: .text(value))
    }

    private func row(_ key: String, _ value: String = "1") -> KeyValue {
        KeyValue(key: key, value: value)
    }

    @Test("A header key that resolves to empty is named as written")
    func header() async {
        let request = Request(name: "List", urlTemplate: "https://example.com", headers: [row("{{x}}")])

        #expect(await sentNotes(request) == [.emptyHeaderName("{{x}}")])
    }

    @Test("Several header keys that resolve to empty are counted")
    func headers() async {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            headers: [row("{{x}}"), row("{{y}}")]
        )

        #expect(await sentNotes(request) == [.emptyHeaderNames(2)])
    }

    @Test("A query key that resolves to empty is named as written")
    func queryParameter() async {
        let request = Request(name: "List", urlTemplate: "https://example.com", queryParameters: [row("{{x}}")])

        #expect(await sentNotes(request) == [.emptyQueryParameterName("{{x}}")])
    }

    @Test("Several query keys that resolve to empty are counted")
    func queryParameters() async {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            queryParameters: [row("{{x}}"), row("{{y}}")]
        )

        #expect(await sentNotes(request) == [.emptyQueryParameterNames(2)])
    }

    @Test("A form-data or URL-encoded key that resolves to empty is named as written")
    func bodyField() async {
        #expect(await sentNotes(post(.formData([field("{{x}}")]))) == [.emptyFieldName("{{x}}")])
        #expect(await sentNotes(post(.urlEncoded([row("{{x}}")]))) == [.emptyFieldName("{{x}}")])
    }

    @Test("Several form-data or URL-encoded keys that resolve to empty are counted")
    func bodyFields() async {
        #expect(await sentNotes(post(.formData([field("{{x}}"), field("{{y}}")]))) == [.emptyFieldNames(2)])
        #expect(await sentNotes(post(.urlEncoded([row("{{x}}"), row("{{y}}")]))) == [.emptyFieldNames(2)])
    }

    @Test("A variable in the value of a row with an empty name has no note")
    func variableInEmptiedRow() async {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            headers: [row("{{x}}", "{{undefined}}")]
        )

        #expect(await sentNotes(request) == [.emptyHeaderName("{{x}}")])
    }

    @Test("A body left off a GET shows its one note, not one for each emptied field")
    func bodyLeftOff() async {
        #expect(await sentNotes(get(.formData([field("{{x}}"), field("sent")]))) == [.bodyNotSent(.get)])
        #expect(await sentNotes(get(.urlEncoded([row("{{x}}"), row("sent")]))) == [.bodyNotSent(.get)])
    }

    @Test("A GET whose fields all have empty names has no body to leave off, so it shows the field note")
    func noBodyToLeaveOff() async {
        #expect(await sentNotes(get(.formData([field("{{x}}")]))) == [.emptyFieldName("{{x}}")])
        #expect(await sentNotes(get(.urlEncoded([row("{{x}}")]))) == [.emptyFieldName("{{x}}")])
    }

    @Test("An empty header name and an invalid one each show their own note")
    func differentReasons() async {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            headers: [row("{{x}}"), row("X Trace")]
        )

        #expect(await sentNotes(request) == [.unsendableHeader("X Trace"), .emptyHeaderName("{{x}}")])
    }

    @Test("A key blank as written shows no note")
    func blankAsWritten() async {
        let request = Request(
            name: "Upload",
            method: .post,
            urlTemplate: "https://example.com",
            queryParameters: [row("")],
            headers: [row("")],
            body: .urlEncoded([row("")])
        )

        #expect(await sentNotes(request).isEmpty)
        #expect(await sentNotes(post(.formData([field("")]))).isEmpty)
    }

    @Test("A disabled row shows no note")
    func disabled() async {
        let disabled = KeyValue(key: "{{x}}", value: "1", isEnabled: false)
        let disabledField = FormDataField(key: "{{x}}", value: .text("1"), isEnabled: false)
        let request = Request(
            name: "Upload",
            method: .post,
            urlTemplate: "https://example.com",
            queryParameters: [disabled],
            headers: [disabled],
            body: .urlEncoded([disabled])
        )

        #expect(await sentNotes(request).isEmpty)
        #expect(await sentNotes(post(.formData([disabledField]))).isEmpty)
    }

    @Test("A transport failure keeps the note on an empty name")
    func transportFailure() async {
        let transport = RecordingTransport {
            throw HTTPTransportError.timedOut(description: "The request timed out.")
        }
        let sender = RequestSender(transport: transport, secretStore: InMemorySecretStore())
        let request = Request(name: "List", urlTemplate: "https://example.com", headers: [row("{{x}}")])

        let result = await sender.send(OutgoingRequest(request: request), scopes: scopes)

        #expect(result == .failed(
            SendFailure(kind: .timedOut, description: "The request timed out."),
            notes: [.emptyHeaderName("{{x}}")]
        ))
    }

}
