//  ResponsePane.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import SwiftUI

struct ResponsePane: View {

    let state: RequestResponses.State?

    @State private var section = ResponseSection.body

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("RESPONSE_PANE_LABEL")
            .accessibilityIdentifier("responsePane")
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case nil:
            ContentUnavailableView(
                "RESPONSE_EMPTY_TITLE",
                systemImage: "arrow.down.doc",
                description: Text("RESPONSE_EMPTY_DESCRIPTION")
            )
        case .sending:
            ProgressView("RESPONSE_SENDING")
        case .finished(.cancelled):
            ContentUnavailableView("RESPONSE_CANCELLED", systemImage: "xmark.circle")
        case .finished(.failed(let failure, let notes)):
            ResponseFailureView(failure: failure, notes: notes)
        case .finished(.response(let response)):
            ResponseView(response: response, section: $section)
        }
    }

}

private extension SentResponse {

    static func preview(body: String = #"{"id":1,"name":"Moth"}"#, notes: [ResponseNote] = []) -> SentResponse {
        SentResponse(
            HTTPResponse(
                status: 200,
                headers: ["Content-Type": "application/json", "Date": "Fri, 06 Nov 2026 09:00:00 GMT"],
                body: Data(body.utf8),
                metrics: HTTPMetrics(
                    totalTime: .milliseconds(142),
                    dns: .milliseconds(12),
                    connect: .milliseconds(30),
                    firstByte: .milliseconds(90),
                    download: .milliseconds(10)
                )
            ),
            measured: .zero,
            notes: notes
        )
    }

}

#Preview("No Response") {
    ResponsePane(state: nil)
        .frame(width: 600, height: 300)
}

#Preview("Sending") {
    ResponsePane(state: .sending)
        .frame(width: 600, height: 300)
}

#Preview("JSON") {
    ResponsePane(state: .finished(.response(.preview())))
        .frame(width: 600, height: 300)
}

#Preview("Notes") {
    ResponsePane(state: .finished(.response(.preview(notes: [.undefinedVariable("host"), .unsupportedAuth]))))
        .frame(width: 600, height: 300)
}

#Preview("All Notes") {
    ResponsePane(state: .finished(.response(.preview(notes: [
        .secretWithNoValue("token"),
        .unsendableHeaders(2),
        .unsupportedAuth,
        .bodyNotSent(.get),
        .unsupportedFile("photo"),
        .formDataBoundaryReplaced
    ]))))
    .frame(width: 600, height: 300)
}

#Preview("All Notes, Short Pane") {
    ResponsePane(state: .finished(.response(.preview(notes: [
        .secretWithNoValue("token"),
        .unsendableHeaders(2),
        .unsupportedAuth,
        .bodyNotSent(.get),
        .unsupportedFile("photo"),
        .formDataBoundaryReplaced
    ]))))
    .frame(width: 400, height: 160)
}

#Preview("Failure") {
    ResponsePane(state: .finished(.failed(
        SendFailure(kind: .couldNotConnect, description: "A server with the specified hostname could not be found."),
        notes: []
    )))
    .frame(width: 600, height: 300)
}

#Preview("Cancelled") {
    ResponsePane(state: .finished(.cancelled))
        .frame(width: 600, height: 300)
}
