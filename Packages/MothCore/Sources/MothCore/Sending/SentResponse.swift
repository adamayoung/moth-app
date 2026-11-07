//  SentResponse.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

public nonisolated struct ResponseHeader: Sendable, Hashable {

    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

}

public nonisolated enum TimingPhase: Sendable, Hashable, Codable {

    case dns
    case connect
    case tls
    case firstByte
    case download

}

public nonisolated struct PhaseTiming: Sendable, Hashable, Codable {

    public let phase: TimingPhase
    public let duration: Duration

    public init(phase: TimingPhase, duration: Duration) {
        self.phase = phase
        self.duration = duration
    }

}

/// Holds what the viewer shows rather than the `HTTPResponse`, so a large body isn't kept twice.
public nonisolated struct SentResponse: Sendable, Hashable {

    public let status: Int
    public let reasonPhrase: String?
    public let duration: Duration
    public let size: Int
    public let headers: [ResponseHeader]
    public let timing: [PhaseTiming]
    public let content: ResponseContent
    public let notes: [ResponseNote]

    /// `measured` stands in when URLSession delivers no metrics before the send returns.
    public init(_ response: HTTPResponse, measured: Duration, notes: [ResponseNote] = []) {
        self.status = response.status
        self.reasonPhrase = response.reasonPhrase
        self.duration = response.metrics?.totalTime ?? measured
        self.size = response.body.count
        self.headers = Self.sorted(response.headers.map { ResponseHeader(name: $0.key, value: $0.value) })
        self.timing = response.metrics.map(Self.timing) ?? []
        self.content = ResponseContent(body: response.body, contentType: response.value(forHeader: "Content-Type"))
        self.notes = notes
    }

    /// A body that wasn't kept shows as empty, and the History view says so.
    public init(_ recorded: HistoryResponse, duration: Duration) {
        self.status = recorded.status
        self.reasonPhrase = recorded.reasonPhrase
        self.duration = duration
        self.size = recorded.size
        self.headers = Self.sorted(recorded.headers.map { ResponseHeader(name: $0.key, value: $0.value) })
        self.timing = recorded.timing
        let contentType = recorded.headers.first { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }
        self.content = ResponseContent(body: recorded.body ?? Data(), contentType: contentType?.value)
        self.notes = []
    }

    public func statusLine(locale: Locale = .autoupdatingCurrent) -> String {
        let status = [String(status), reasonPhrase].compactMap(\.self).joined(separator: " ")
        return [status, duration.responseText(locale: locale), size.byteCountText].joined(separator: " · ")
    }

    private static func sorted(_ headers: [ResponseHeader]) -> [ResponseHeader] {
        headers.sorted { $0.name.caseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func timing(_ metrics: HTTPMetrics) -> [PhaseTiming] {
        let phases: [(TimingPhase, Duration?)] = [
            (.dns, metrics.dns),
            (.connect, metrics.connect),
            (.tls, metrics.tls),
            (.firstByte, metrics.firstByte),
            (.download, metrics.download)
        ]
        return phases.compactMap { phase, duration in
            duration.map { PhaseTiming(phase: phase, duration: $0) }
        }
    }

}

public nonisolated extension Duration {

    func responseText(locale: Locale = .autoupdatingCurrent) -> String {
        guard self >= .seconds(1) else {
            return formatted(.units(allowed: [.milliseconds], width: .abbreviated).locale(locale))
        }
        return formatted(
            .units(allowed: [.seconds], width: .abbreviated, fractionalPart: .show(length: 2)).locale(locale)
        )
    }

}

public nonisolated extension Int {

    /// `ByteCountFormatStyle` writes 1,234 bytes as "1 kB". An adaptive formatter drops that decimal too.
    var byteCountText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.isAdaptive = false
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(self))
    }

}
