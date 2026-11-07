//  RequestSenderPathVariableTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Testing

struct RequestSenderPathVariableTests {

    private let scopes = VariableScopes(environment: [
        Variable(name: "empty", value: .plain(initial: "", current: "")),
        Variable(name: "name", value: .plain(initial: "hidden", current: "")),
        Variable(name: "base", value: .plain(initial: "https://example.com/:hidden", current: ""))
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

    @Test("A path variable with no value is named, however it came to have none", arguments: [
        [KeyValue(key: "id", value: "")],
        [KeyValue(key: "id", value: "{{empty}}")],
        [KeyValue(key: "id", value: "1", isEnabled: false)],
        []
    ])
    func noValue(rows: [KeyValue]) async {
        let request = Request(name: "User", urlTemplate: "https://example.com/users/:id", pathParameters: rows)

        #expect(await sentNotes(request) == [.pathVariableWithoutValue("id")])
    }

    @Test("Several path variables with no value are counted")
    func severalWithNoValue() async {
        let request = Request(
            name: "Post",
            urlTemplate: "https://example.com/users/:id/posts/:post",
            pathParameters: [KeyValue(key: "id", value: ""), KeyValue(key: "post", value: "")]
        )

        #expect(await sentNotes(request) == [.pathVariablesWithoutValues(2)])
    }

    @Test("A path variable used twice is one note")
    func usedTwice() async {
        let request = Request(
            name: "Mirror",
            urlTemplate: "https://example.com/:id/copies/:id",
            pathParameters: [KeyValue(key: "id", value: "")]
        )

        #expect(await sentNotes(request) == [.pathVariableWithoutValue("id")])
    }

    @Test("A path variable with a value shows no note")
    func filled() async {
        let request = Request(
            name: "User",
            urlTemplate: "https://example.com/users/:id",
            pathParameters: [KeyValue(key: "id", value: "1")]
        )

        #expect(await sentNotes(request).isEmpty)
    }

    @Test("A path variable holding an undefined variable keeps that variable's note and gets no path note")
    func undefinedValue() async {
        let request = Request(
            name: "User",
            urlTemplate: "https://example.com/users/:id",
            pathParameters: [KeyValue(key: "id", value: "{{undefined}}")]
        )

        #expect(await sentNotes(request) == [.undefinedVariable("undefined")])
    }

    @Test("A path variable named by a variable is named as written, so a secret stays hidden")
    func namedAsWritten() async {
        let request = Request(
            name: "User",
            urlTemplate: "https://example.com/users/:{{name}}",
            pathParameters: [KeyValue(key: "{{name}}", value: "")]
        )

        #expect(await sentNotes(request) == [.pathVariableWithoutValue("{{name}}")])
    }

    @Test("A path variable the tab doesn't show is counted, not named", arguments: [
        ("{{base}}/users", [KeyValue]()),
        ("https://example.com/users/:{{name}}", [KeyValue(key: "{{name}}", value: "", isEnabled: false)])
    ])
    func hiddenFromTheTab(url: String, rows: [KeyValue]) async {
        let request = Request(name: "User", urlTemplate: url, pathParameters: rows)

        #expect(await sentNotes(request) == [.pathVariablesWithoutValues(1)])
    }

    @Test("A named and a hidden path variable are counted together")
    func namedAndHidden() async {
        let request = Request(name: "User", urlTemplate: "{{base}}/:id")

        #expect(await sentNotes(request) == [.pathVariablesWithoutValues(2)])
    }

    @Test("A transport failure keeps the note on a path variable")
    func transportFailure() async {
        let transport = RecordingTransport {
            throw HTTPTransportError.timedOut(description: "The request timed out.")
        }
        let sender = RequestSender(transport: transport, secretStore: InMemorySecretStore())
        let request = Request(name: "User", urlTemplate: "https://example.com/users/:id")

        let result = await sender.send(OutgoingRequest(request: request), scopes: scopes)

        #expect(result == .failed(
            SendFailure(kind: .timedOut, description: "The request timed out."),
            notes: [.pathVariableWithoutValue("id")]
        ))
    }

}
