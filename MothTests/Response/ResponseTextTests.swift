//  ResponseTextTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import Testing

@MainActor
struct ResponseTextTests {

    @Test(
        "Each failure has its title",
        arguments: [
            (SendFailure.Kind.couldNotConnect, "Couldn\u{2019}t Connect"),
            (SendFailure.Kind.timedOut, "Request Timed Out"),
            (SendFailure.Kind.notSent, "Couldn\u{2019}t Send")
        ]
    )
    func failureTitle(kind: SendFailure.Kind, title: String) {
        #expect(kind.title == title)
    }

    @Test(
        "Each note reads as the issue words it",
        arguments: [
            (
                ResponseNote.undefinedVariable("name"),
                "{{name}} isn\u{2019}t defined, so it was sent as written."
            ),
            (ResponseNote.undefinedVariables(3), "3 variables aren\u{2019}t defined and were sent as written."),
            (ResponseNote.undefinedVariables(1), "1 variable isn\u{2019}t defined and was sent as written."),
            (ResponseNote.missingCredential, "Sent without auth, because its credential has no value."),
            (ResponseNote.unsupportedAuth, "Sent without its unsupported auth."),
            (ResponseNote.unsupportedBody, "Sent without its unsupported body.")
        ]
    )
    func noteMessage(note: ResponseNote, message: String) {
        #expect(note.message == message)
    }

    @Test(
        "A variable's note gives its reason",
        arguments: [
            (
                ResponseNote.secretWithNoValue("token"),
                "{{token}} is a secret with no value, so it was sent as written."
            ),
            (ResponseNote.variableCycle("a"), "{{a}} refers to itself, so it was sent as written."),
            (ResponseNote.variableNotExpanded("a"), "{{a}} couldn\u{2019}t be expanded, so it was sent as written."),
            (ResponseNote.unresolvedVariables(3), "3 variables couldn\u{2019}t be resolved and were sent as written."),
            (ResponseNote.unresolvedVariables(1), "1 variable couldn\u{2019}t be resolved and was sent as written.")
        ]
    )
    func variableNoteMessage(note: ResponseNote, message: String) {
        #expect(note.message == message)
    }

    @Test(
        "A note on what was left out says what and why",
        arguments: [
            (
                ResponseNote.unsendableHeader("X-Trace"),
                "Sent without header X-Trace, because its name or value isn\u{2019}t valid."
            ),
            (
                ResponseNote.unsendableHeaders(2),
                "Sent without 2 headers, because their names or values aren\u{2019}t valid."
            ),
            (
                ResponseNote.unsendableHeaders(1),
                "Sent without 1 header, because its name or value isn\u{2019}t valid."
            ),
            (
                ResponseNote.unsupportedFile("photo"),
                "Sent without file photo, because Moth can\u{2019}t send files yet."
            ),
            (ResponseNote.unsupportedFiles(2), "Sent without 2 files, because Moth can\u{2019}t send files yet."),
            (ResponseNote.unsupportedFiles(1), "Sent without 1 file, because Moth can\u{2019}t send files yet."),
            (ResponseNote.bodyNotSent(.get), "Sent without its body, because Moth can\u{2019}t send a body with GET."),
            (
                ResponseNote.bodyNotSent(.head),
                "Sent without its body, because Moth can\u{2019}t send a body with HEAD."
            ),
            (
                ResponseNote.bodyNotSent(HTTPMethod(rawValue: "get")),
                "Sent without its body, because Moth can\u{2019}t send a body with GET."
            ),
            (
                ResponseNote.formDataBoundaryReplaced,
                "Your Content-Type header replaced the form-data boundary, so the server may not read the body."
            )
        ]
    )
    func leftOutNoteMessage(note: ResponseNote, message: String) {
        #expect(note.message == message)
    }

    @Test(
        "A note on an empty name says which row and why",
        arguments: [
            (ResponseNote.emptyHeaderName("{{x}}"), "Sent without header {{x}}, because its name is empty."),
            (ResponseNote.emptyHeaderNames(2), "Sent without 2 headers, because their names are empty."),
            (ResponseNote.emptyHeaderNames(1), "Sent without 1 header, because its name is empty."),
            (ResponseNote.emptyFieldName("{{x}}"), "Sent without field {{x}}, because its name is empty."),
            (ResponseNote.emptyFieldNames(2), "Sent without 2 fields, because their names are empty."),
            (ResponseNote.emptyFieldNames(1), "Sent without 1 field, because its name is empty."),
            (
                ResponseNote.emptyQueryParameterName("{{x}}"),
                "Sent without query parameter {{x}}, because its name is empty."
            ),
            (
                ResponseNote.emptyQueryParameterNames(2),
                "Sent without 2 query parameters, because their names are empty."
            ),
            (ResponseNote.emptyQueryParameterNames(1), "Sent without 1 query parameter, because its name is empty.")
        ]
    )
    func emptyNameNoteMessage(note: ResponseNote, message: String) {
        #expect(note.message == message)
    }

    @Test(
        "A note on a path variable says it went out as written",
        arguments: [
            (ResponseNote.pathVariableWithoutValue("id"), ":id has no value, so it was sent as written."),
            (ResponseNote.pathVariablesWithoutValues(2), "2 path variables have no value and were sent as written."),
            (ResponseNote.pathVariablesWithoutValues(1), "1 path variable has no value and was sent as written.")
        ]
    )
    func pathVariableNoteMessage(note: ResponseNote, message: String) {
        #expect(note.message == message)
    }

    @Test(
        "Each timing phase has its title",
        arguments: [
            (TimingPhase.dns, "DNS"),
            (TimingPhase.connect, "Connect"),
            (TimingPhase.tls, "TLS"),
            (TimingPhase.firstByte, "First Byte"),
            (TimingPhase.download, "Download")
        ]
    )
    func phaseTitle(phase: TimingPhase, title: String) {
        #expect(phase.title == title)
    }

    @Test("Each section has its title", arguments: [
        (ResponseSection.body, "Body"), (ResponseSection.headers, "Headers"), (ResponseSection.timing, "Timing")
    ])
    func sectionTitle(section: ResponseSection, title: String) {
        #expect(section.title == title)
    }

}
