//  HTTPMetrics.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public struct HTTPMetrics: Equatable, Sendable {

    public let totalTime: Duration
    public let dns: Duration?
    public let connect: Duration?
    public let tls: Duration?
    public let firstByte: Duration?
    public let download: Duration?
    public let negotiatedProtocol: String?
    public let bytesReceived: Int64
    public let redirectCount: Int

    public init(
        totalTime: Duration,
        dns: Duration? = nil,
        connect: Duration? = nil,
        tls: Duration? = nil,
        firstByte: Duration? = nil,
        download: Duration? = nil,
        negotiatedProtocol: String? = nil,
        bytesReceived: Int64 = 0,
        redirectCount: Int = 0
    ) {
        self.totalTime = totalTime
        self.dns = dns
        self.connect = connect
        self.tls = tls
        self.firstByte = firstByte
        self.download = download
        self.negotiatedProtocol = negotiatedProtocol
        self.bytesReceived = bytesReceived
        self.redirectCount = redirectCount
    }

    init(recorded: RecordedTaskMetrics) {
        let transaction = recorded.finalTransaction
        self.init(
            totalTime: .seconds(recorded.taskDuration),
            dns: Self.elapsed(from: transaction?.domainLookupStart, to: transaction?.domainLookupEnd),
            connect: Self.elapsed(
                from: transaction?.connectStart,
                to: transaction?.secureConnectionStart ?? transaction?.connectEnd
            ),
            tls: Self.elapsed(from: transaction?.secureConnectionStart, to: transaction?.secureConnectionEnd),
            firstByte: Self.elapsed(from: transaction?.requestStart, to: transaction?.responseStart),
            download: Self.elapsed(from: transaction?.responseStart, to: transaction?.responseEnd),
            negotiatedProtocol: transaction?.networkProtocolName,
            bytesReceived: (transaction?.responseHeaderBytes ?? 0) + (transaction?.responseBodyBytes ?? 0),
            redirectCount: recorded.redirectCount
        )
    }

    private static func elapsed(from start: Date?, to end: Date?) -> Duration? {
        guard let start, let end else {
            return nil
        }
        return .seconds(end.timeIntervalSince(start))
    }

}
