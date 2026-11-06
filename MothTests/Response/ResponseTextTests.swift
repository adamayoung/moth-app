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
