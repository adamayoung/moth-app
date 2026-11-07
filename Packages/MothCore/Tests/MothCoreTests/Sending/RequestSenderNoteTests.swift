//  RequestSenderNoteTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Testing

struct RequestSenderNoteTests {

    private func send(
        _ request: Request,
        scopes: VariableScopes = VariableScopes(),
        through transport: RecordingTransport = RecordingTransport()
    ) async -> SendResult {
        let sender = RequestSender(transport: transport, secretStore: InMemorySecretStore())
        return await sender.send(OutgoingRequest(request: request), scopes: scopes)
    }

    @Test("A GET goes out without its unsendable header and its body, and says so")
    func unsendableHeaderAndBodyOnGet() async {
        let transport = RecordingTransport()
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "X Trace", value: "1")],
            body: .raw(content: "{}", contentType: "application/json")
        )

        let result = await send(request, through: transport)

        guard case .response(let response) = result else {
            Issue.record("Expected a response, got \(result)")
            return
        }
        #expect(transport.requests.first?.httpBody == nil)
        #expect(response.notes == [.unsendableHeader("X Trace"), .bodyNotSent(.get)])
    }

    @Test("A form-data file and a manual Content-Type are noted")
    func formDataNotes() async {
        let request = Request(
            name: "Upload",
            method: .post,
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "Content-Type", value: "multipart/form-data")],
            body: .formData([FormDataField(key: "photo", value: .file(paths: ["/tmp/photo.png"]))])
        )

        let result = await send(request)

        guard case .response(let response) = result else {
            Issue.record("Expected a response, got \(result)")
            return
        }
        #expect(response.notes == [.unsupportedFile("photo"), .formDataBoundaryReplaced])
    }

    @Test("A cycle and a secret with no value are noted by reason", arguments: [
        ([Variable(name: "a", value: .plain(initial: "{{a}}", current: ""))], ResponseNote.variableCycle("a")),
        ([Variable(name: "a", value: .secret(SecretReference(identifier: "a")))], .secretWithNoValue("a"))
    ])
    func notedByReason(variables: [Variable], note: ResponseNote) async {
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            headers: [KeyValue(key: "X-Token", value: "{{a}}")]
        )

        let result = await send(request, scopes: VariableScopes(environment: variables))

        guard case .response(let response) = result else {
            Issue.record("Expected a response, got \(result)")
            return
        }
        #expect(response.notes == [note])
    }

    @Test("A transport failure keeps a note on what was left out")
    func transportFailureKeepsLeftOutNote() async {
        let transport = RecordingTransport {
            throw HTTPTransportError.timedOut(description: "The request timed out.")
        }
        let request = Request(
            name: "List",
            urlTemplate: "https://example.com",
            body: .raw(content: "{}", contentType: "application/json")
        )

        let result = await send(request, through: transport)

        #expect(result == .failed(
            SendFailure(kind: .timedOut, description: "The request timed out."),
            notes: [.bodyNotSent(.get)]
        ))
    }

}
