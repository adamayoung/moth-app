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

    @Test("One unresolved variable is noted by its reason", arguments: [
        (UnresolvedReason.missingSecret, ResponseNote.secretWithNoValue("token")),
        (.cycle, .variableCycle("token")),
        (.tooDeep, .variableNotExpanded("token")),
        (.tooLarge, .variableNotExpanded("token"))
    ])
    func oneVariableByReason(reason: UnresolvedReason, note: ResponseNote) {
        let unresolved = [UnresolvedVariable(name: "token", reason: reason)]

        #expect(ResponseNote.notes(unresolved: unresolved, notices: []) == [note])
    }

    @Test("Several variables with any reason but undefined count as unresolved", arguments: [
        [UnresolvedReason.undefined, .missingSecret],
        [.cycle, .tooDeep, .tooLarge]
    ])
    func severalVariablesWithOtherReasons(reasons: [UnresolvedReason]) {
        let unresolved = reasons.enumerated().map { index, reason in
            UnresolvedVariable(name: "v\(index)", reason: reason)
        }

        #expect(ResponseNote.notes(unresolved: unresolved, notices: []) == [.unresolvedVariables(reasons.count)])
    }

    @Test("One unsendable header is named")
    func oneUnsendableHeader() {
        let notes = ResponseNote.notes(unresolved: [], notices: [.unsendableHeader(name: "X-Trace")])

        #expect(notes == [.unsendableHeader("X-Trace")])
    }

    @Test("Several unsendable headers are counted")
    func severalUnsendableHeaders() {
        let notices: [RequestBuildNotice] = [.unsendableHeader(name: "A"), .unsendableHeader(name: "B")]

        #expect(ResponseNote.notes(unresolved: [], notices: notices) == [.unsendableHeaders(2)])
    }

    @Test("Two rows with the same bad header name read as one header")
    func repeatedUnsendableHeader() {
        let notices: [RequestBuildNotice] = [.unsendableHeader(name: "A"), .unsendableHeader(name: "A")]

        #expect(ResponseNote.notes(unresolved: [], notices: notices) == [.unsendableHeader("A")])
    }

    @Test("One unsupported file is named")
    func oneUnsupportedFile() {
        let notes = ResponseNote.notes(unresolved: [], notices: [.unsupportedFormDataFile(key: "photo")])

        #expect(notes == [.unsupportedFile("photo")])
    }

    @Test("Several unsupported files are counted")
    func severalUnsupportedFiles() {
        let notices: [RequestBuildNotice] = [
            .unsupportedFormDataFile(key: "front"),
            .unsupportedFormDataFile(key: "back")
        ]

        #expect(ResponseNote.notes(unresolved: [], notices: notices) == [.unsupportedFiles(2)])
    }

    @Test("Two rows with the same file key read as one file")
    func repeatedUnsupportedFile() {
        let notices: [RequestBuildNotice] = [
            .unsupportedFormDataFile(key: "photo"),
            .unsupportedFormDataFile(key: "photo")
        ]

        #expect(ResponseNote.notes(unresolved: [], notices: notices) == [.unsupportedFile("photo")])
    }

    @Test("An unsupported auth is noted")
    func unsupportedAuth() {
        #expect(ResponseNote.notes(unresolved: [], notices: [.unsupportedAuth(.oauth2)]) == [.unsupportedAuth])
    }

    @Test("An unsupported body is noted", arguments: [UnsupportedBodyKind.binary, .graphQL])
    func unsupportedBody(kind: UnsupportedBodyKind) {
        #expect(ResponseNote.notes(unresolved: [], notices: [.unsupportedBody(kind)]) == [.unsupportedBody])
    }

    @Test("A credential with no value is noted, because the request went out without auth")
    func missingCredential() {
        let notes = ResponseNote.notes(
            unresolved: [],
            notices: [],
            unresolvedCredentials: [SecretReference(identifier: "token")]
        )

        #expect(notes == [.missingCredential])
    }

    @Test("An unsupported auth with no credential is noted once, as unsupported")
    func unsupportedAuthWithNoCredential() {
        let notes = ResponseNote.notes(
            unresolved: [],
            notices: [.unsupportedAuth(.oauth2)],
            unresolvedCredentials: [SecretReference(identifier: "key")]
        )

        #expect(notes == [.unsupportedAuth])
    }

    @Test("Notes keep one order, with variables first")
    func order() {
        let notes = ResponseNote.notes(
            unresolved: unresolved("host"),
            notices: [.unsupportedBody(.binary), .unsupportedAuth(.oauth2)]
        )

        #expect(notes == [.undefinedVariable("host"), .unsupportedAuth, .unsupportedBody])
    }

    @Test("A body left off keeps its method", arguments: [HTTPMethod.get, .head])
    func bodyNotSent(method: HTTPMethod) {
        #expect(ResponseNote.notes(unresolved: [], notices: [.bodyNotSent(method: method)]) == [.bodyNotSent(method)])
    }

    @Test("A replaced form-data boundary is noted")
    func boundaryReplaced() {
        let notes = ResponseNote.notes(unresolved: [], notices: [.formDataBoundaryNotDeclared])

        #expect(notes == [.formDataBoundaryReplaced])
    }

    @Test("A form-data file on GET shows both the file and the body note")
    func fileOnBodilessMethod() {
        let notices: [RequestBuildNotice] = [.unsupportedFormDataFile(key: "photo"), .bodyNotSent(method: .get)]

        #expect(ResponseNote.notes(unresolved: [], notices: notices) == [.bodyNotSent(.get), .unsupportedFile("photo")])
    }

    @Test("Every kind of note keeps one order")
    func orderOfEveryKind() {
        let notices: [RequestBuildNotice] = [
            .formDataBoundaryNotDeclared,
            .unsupportedFormDataFile(key: "photo"),
            .unsupportedBody(.binary),
            .bodyNotSent(method: .get),
            .unsupportedAuth(.oauth2),
            .unsendableHeader(name: "X-Trace")
        ]

        #expect(ResponseNote.notes(unresolved: unresolved("host"), notices: notices) == [
            .undefinedVariable("host"),
            .unsendableHeader("X-Trace"),
            .unsupportedAuth,
            .bodyNotSent(.get),
            .unsupportedBody,
            .unsupportedFile("photo"),
            .formDataBoundaryReplaced
        ])
    }

}
