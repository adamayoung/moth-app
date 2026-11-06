//  SendFailureTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Testing

struct SendFailureTests {

    private struct OtherError: LocalizedError {

        var errorDescription: String? {
            "Something else."
        }

    }

    @Test("A timeout keeps the system's description")
    func timedOut() {
        let failure = SendFailure(transportError: HTTPTransportError.timedOut(description: "The request timed out."))

        #expect(failure == SendFailure(kind: .timedOut, description: "The request timed out."))
    }

    @Test(
        "A connection, TLS or other transport failure reads as a failure to connect",
        arguments: [
            HTTPTransportError.connectionFailed(description: "No host."),
            HTTPTransportError.tlsFailed(description: "No host."),
            HTTPTransportError.failed(description: "No host.")
        ]
    )
    func couldNotConnect(error: HTTPTransportError) {
        #expect(SendFailure(transportError: error) == SendFailure(kind: .couldNotConnect, description: "No host."))
    }

    @Test("A reply that isn't HTTP has no system description")
    func notHTTP() {
        #expect(
            SendFailure(transportError: HTTPTransportError.notHTTP)
                == SendFailure(kind: .couldNotConnect, description: nil)
        )
    }

    @Test("Any other error from the transport keeps its description")
    func otherTransportError() {
        #expect(
            SendFailure(transportError: OtherError())
                == SendFailure(kind: .couldNotConnect, description: "Something else.")
        )
    }

    @Test("A request that couldn't be built was not sent")
    func notSent() {
        #expect(
            SendFailure(notSent: RequestBuildError.invalidURL)
                == SendFailure(kind: .notSent, description: "This URL isn’t valid.")
        )
    }

}
