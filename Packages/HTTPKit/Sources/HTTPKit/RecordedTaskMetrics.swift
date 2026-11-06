//  RecordedTaskMetrics.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

struct RecordedTaskMetrics: Sendable {

    struct Transaction: Sendable {
        var domainLookupStart: Date?
        var domainLookupEnd: Date?
        var connectStart: Date?
        var secureConnectionStart: Date?
        var secureConnectionEnd: Date?
        var connectEnd: Date?
        var requestStart: Date?
        var responseStart: Date?
        var responseEnd: Date?
        var networkProtocolName: String?
        var responseHeaderBytes: Int64 = 0
        var responseBodyBytes: Int64 = 0
    }

    var taskDuration: TimeInterval
    var redirectCount: Int
    var finalTransaction: Transaction?

}

extension RecordedTaskMetrics {

    init(_ metrics: URLSessionTaskMetrics) {
        self.init(
            taskDuration: metrics.taskInterval.duration,
            redirectCount: metrics.redirectCount,
            finalTransaction: metrics.transactionMetrics.last.map(Transaction.init)
        )
    }

}

extension RecordedTaskMetrics.Transaction {

    init(_ metrics: URLSessionTaskTransactionMetrics) {
        self.init(
            domainLookupStart: metrics.domainLookupStartDate,
            domainLookupEnd: metrics.domainLookupEndDate,
            connectStart: metrics.connectStartDate,
            secureConnectionStart: metrics.secureConnectionStartDate,
            secureConnectionEnd: metrics.secureConnectionEndDate,
            connectEnd: metrics.connectEndDate,
            requestStart: metrics.requestStartDate,
            responseStart: metrics.responseStartDate,
            responseEnd: metrics.responseEndDate,
            networkProtocolName: metrics.networkProtocolName,
            responseHeaderBytes: metrics.countOfResponseHeaderBytesReceived,
            responseBodyBytes: metrics.countOfResponseBodyBytesReceived
        )
    }

}
