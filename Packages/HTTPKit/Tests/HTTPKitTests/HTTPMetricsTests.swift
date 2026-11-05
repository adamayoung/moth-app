//  HTTPMetricsTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import HTTPKit
import Testing

struct HTTPMetricsTests {

    private let start = Date(timeIntervalSinceReferenceDate: 1000)

    private func date(_ offset: TimeInterval) -> Date {
        start.addingTimeInterval(offset)
    }

    @Test("Total time and every phase come from the recorded dates")
    func mapsTheTotalTimeAndPhases() {
        let recorded = RecordedTaskMetrics(
            taskDuration: 16,
            redirectCount: 0,
            finalTransaction: .init(
                domainLookupStart: date(0),
                domainLookupEnd: date(1),
                connectStart: date(1),
                secureConnectionStart: date(3),
                secureConnectionEnd: date(7),
                connectEnd: date(7),
                requestStart: date(7),
                responseStart: date(8),
                responseEnd: date(16)
            )
        )

        let metrics = HTTPMetrics(recorded: recorded)

        #expect(metrics.totalTime == .seconds(16))
        #expect(metrics.dns == .seconds(1))
        #expect(metrics.tls == .seconds(4))
        #expect(metrics.firstByte == .seconds(1))
        #expect(metrics.download == .seconds(8))
    }

    @Test("Connect stops where the TLS handshake starts, because the connection's end date includes it")
    func connectExcludesTheTLSHandshake() {
        let recorded = RecordedTaskMetrics(
            taskDuration: 7,
            redirectCount: 0,
            finalTransaction: .init(
                connectStart: date(1),
                secureConnectionStart: date(3),
                secureConnectionEnd: date(7),
                connectEnd: date(7)
            )
        )

        #expect(HTTPMetrics(recorded: recorded).connect == .seconds(2))
    }

    @Test("Connect runs to the connection's end date when there was no TLS")
    func connectRunsToItsEndWithoutTLS() {
        let recorded = RecordedTaskMetrics(
            taskDuration: 3,
            redirectCount: 0,
            finalTransaction: .init(connectStart: date(1), connectEnd: date(3))
        )

        #expect(HTTPMetrics(recorded: recorded).connect == .seconds(2))
    }

    @Test("A reused connection has no DNS, connect or TLS phase, and keeps the phases it did have")
    func aReusedConnectionHasNoSetUpPhases() {
        let recorded = RecordedTaskMetrics(
            taskDuration: 3,
            redirectCount: 0,
            finalTransaction: .init(requestStart: date(0), responseStart: date(1), responseEnd: date(3))
        )

        let metrics = HTTPMetrics(recorded: recorded)

        #expect(metrics.dns == nil)
        #expect(metrics.connect == nil)
        #expect(metrics.tls == nil)
        #expect(metrics.firstByte == .seconds(1))
        #expect(metrics.download == .seconds(2))
    }

    @Test("A phase with only one of its dates is absent")
    func aPhaseMissingOneDateIsAbsent() {
        let recorded = RecordedTaskMetrics(
            taskDuration: 1,
            redirectCount: 0,
            finalTransaction: .init(domainLookupStart: date(0), responseEnd: date(1))
        )

        let metrics = HTTPMetrics(recorded: recorded)

        #expect(metrics.dns == nil)
        #expect(metrics.download == nil)
    }

    @Test("A phase that took no measurable time is zero, not absent")
    func aZeroLengthPhaseIsNotAbsent() {
        let recorded = RecordedTaskMetrics(
            taskDuration: 0,
            redirectCount: 0,
            finalTransaction: .init(domainLookupStart: date(0), domainLookupEnd: date(0))
        )

        #expect(HTTPMetrics(recorded: recorded).dns == .zero)
    }

    @Test("Protocol, bytes and redirects come from the recorded metrics, and bytes count headers and body")
    func mapsTheProtocolBytesAndRedirects() {
        let recorded = RecordedTaskMetrics(
            taskDuration: 1,
            redirectCount: 2,
            finalTransaction: .init(
                networkProtocolName: "h2",
                responseHeaderBytes: 120,
                responseBodyBytes: 3400
            )
        )

        let metrics = HTTPMetrics(recorded: recorded)

        #expect(metrics.negotiatedProtocol == "h2")
        #expect(metrics.bytesReceived == 3520)
        #expect(metrics.redirectCount == 2)
    }

    @Test("A task with no transaction has no phases, no protocol and no bytes")
    func aTaskWithNoTransaction() {
        let metrics = HTTPMetrics(
            recorded: RecordedTaskMetrics(taskDuration: 1, redirectCount: 0, finalTransaction: nil)
        )

        #expect(metrics == HTTPMetrics(totalTime: .seconds(1)))
    }

}
