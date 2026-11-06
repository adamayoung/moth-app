//  HTTPTransportErrorTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import HTTPKit
import Testing

struct HTTPTransportErrorTests {

    @Test(
        "A failure's localized description is the system's own",
        arguments: [
            HTTPTransportError.timedOut(description: "The system's words"),
            .connectionFailed(description: "The system's words"),
            .tlsFailed(description: "The system's words"),
            .failed(description: "The system's words")
        ]
    )
    func localizedDescriptionIsTheSystems(error: HTTPTransportError) {
        #expect(error.localizedDescription == "The system's words")
    }

    @Test("A Swift cancellation stays a cancellation")
    func aCancellationIsNotTranslatedToAFailure() {
        #expect(HTTPTransportError.translating(CancellationError()) is CancellationError)
    }

}
