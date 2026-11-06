//  ResponseNoteTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct ResponseNoteTests {

    private func unresolved(_ names: String...) -> [UnresolvedVariable] {
        names.map { UnresolvedVariable(name: $0, reason: .undefined) }
    }

    @Test("Nothing unresolved and nothing unsupported leaves no notes")
    func none() {
        #expect(ResponseNote.notes(unresolved: [], notices: []).isEmpty)
    }

    @Test("One unresolved variable is named")
    func oneVariable() {
        #expect(ResponseNote.notes(unresolved: unresolved("host"), notices: []) == [.undefinedVariable("host")])
    }

    @Test("Several unresolved variables are counted")
    func severalVariables() {
        #expect(ResponseNote.notes(unresolved: unresolved("a", "b", "c"), notices: []) == [.undefinedVariables(3)])
    }

    @Test("A variable that resolves to nothing for another reason reads the same")
    func otherReasons() {
        let unresolved = [UnresolvedVariable(name: "token", reason: .missingSecret)]

        #expect(ResponseNote.notes(unresolved: unresolved, notices: []) == [.undefinedVariable("token")])
    }

    @Test("An unsupported auth is noted", arguments: [
        UnsupportedAuthKind.apiKey, .digest, .oauth2, .awsSigV4
    ])
    func unsupportedAuth(kind: UnsupportedAuthKind) {
        #expect(ResponseNote.notes(unresolved: [], notices: [.unsupportedAuth(kind)]) == [.unsupportedAuth])
    }

    @Test("An unsupported body is noted", arguments: [UnsupportedBodyKind.binary, .graphQL])
    func unsupportedBody(kind: UnsupportedBodyKind) {
        #expect(ResponseNote.notes(unresolved: [], notices: [.unsupportedBody(kind)]) == [.unsupportedBody])
    }

    @Test("Notes keep one order, with variables first")
    func order() {
        let notes = ResponseNote.notes(
            unresolved: unresolved("host"),
            notices: [.unsupportedBody(.binary), .unsupportedAuth(.apiKey)]
        )

        #expect(notes == [.undefinedVariable("host"), .unsupportedAuth, .unsupportedBody])
    }

    @Test("A notice the issue doesn't name adds no note")
    func otherNotices() {
        let notices: [RequestBuildNotice] = [
            .unsupportedFormDataFile(key: "photo"),
            .unsendableHeader(name: "X"),
            .bodyNotSent(method: .get),
            .formDataBoundaryNotDeclared
        ]

        #expect(ResponseNote.notes(unresolved: [], notices: notices).isEmpty)
    }

}
