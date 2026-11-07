//  SentResponseTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Testing

struct SentResponseTests {

    private let locale = Locale(identifier: "en_GB")

    private func response(
        status: Int = 200,
        headers: [String: String] = [:],
        size: Int = 1200,
        metrics: HTTPMetrics? = HTTPMetrics(totalTime: .milliseconds(142))
    ) -> HTTPResponse {
        HTTPResponse(status: status, headers: headers, body: Data(repeating: 0x41, count: size), metrics: metrics)
    }

    @Test("The status line reads status, time and size")
    func statusLine() {
        let sent = SentResponse(response(), measured: .seconds(9))

        #expect(sent.statusLine(locale: locale) == "200 OK · 142 ms · 1.2 KB")
    }

    @Test("A response with no metrics shows the time Moth measured")
    func measuredTime() {
        let sent = SentResponse(response(size: 2, metrics: nil), measured: .milliseconds(90))

        #expect(sent.statusLine(locale: locale) == "200 OK · 90 ms · 2 bytes")
    }

    @Test("A status with no phrase shows its number alone")
    func unknownStatus() {
        let sent = SentResponse(response(status: 299), measured: .zero)

        #expect(sent.statusLine(locale: locale) == "299 · 142 ms · 1.2 KB")
    }

    @Test("An empty body reads as zero bytes, not as a word")
    func emptyBody() {
        let sent = SentResponse(response(status: 204, size: 0), measured: .zero)

        #expect(sent.statusLine(locale: locale) == "204 No Content · 142 ms · 0 bytes")
    }

    @Test("A size keeps three significant figures")
    func threeFigures() {
        let sent = SentResponse(response(size: 1234), measured: .zero)

        #expect(sent.statusLine(locale: locale) == "200 OK · 142 ms · 1.23 KB")
    }

    @Test("A second or more reads in seconds")
    func seconds() {
        let sent = SentResponse(response(metrics: HTTPMetrics(totalTime: .milliseconds(1250))), measured: .zero)

        #expect(sent.statusLine(locale: locale) == "200 OK · 1.25 secs · 1.2 KB")
    }

    @Test("Timing lists only the phases that happened, in the order they ran")
    func timing() {
        let metrics = HTTPMetrics(
            totalTime: .milliseconds(100),
            dns: .milliseconds(1),
            tls: .milliseconds(3),
            download: .milliseconds(5)
        )

        let sent = SentResponse(response(metrics: metrics), measured: .zero)

        #expect(sent.timing == [
            PhaseTiming(phase: .dns, duration: .milliseconds(1)),
            PhaseTiming(phase: .tls, duration: .milliseconds(3)),
            PhaseTiming(phase: .download, duration: .milliseconds(5))
        ])
    }

    @Test("A response with no metrics has no phases")
    func noPhases() {
        #expect(SentResponse(response(metrics: nil), measured: .zero).timing.isEmpty)
    }

    @Test("Headers sort by name whatever their case, because a dictionary has no order")
    func sortedHeaders() {
        let sent = SentResponse(response(headers: ["b": "2", "C": "3", "A": "1"]), measured: .zero)

        #expect(sent.headers == [
            ResponseHeader(name: "A", value: "1"),
            ResponseHeader(name: "b", value: "2"),
            ResponseHeader(name: "C", value: "3")
        ])
    }

    @Test("The content comes from the body and the Content-Type header in any case")
    func content() {
        let body = Data([0x00, 0x01])
        let sent = SentResponse(
            HTTPResponse(status: 200, headers: ["content-TYPE": "image/png"], body: body),
            measured: .zero
        )

        #expect(sent.content == .binary(contentType: "image/png", size: 2))
    }

    @Test("Notes are kept")
    func notes() {
        let sent = SentResponse(response(), measured: .zero, notes: [.unsupportedAuth])

        #expect(sent.notes == [.unsupportedAuth])
    }

}
