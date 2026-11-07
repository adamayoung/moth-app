//  RecordingHTTPTransport.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Synchronization

final nonisolated class RecordingHTTPTransport: HTTPTransport {

    private let sent = Mutex<[URLRequest]>([])

    var requests: [URLRequest] {
        sent.withLock(\.self)
    }

    @concurrent
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        sent.withLock { $0.append(request) }
        return HTTPResponse(status: 200, headers: [:], body: Data("{}".utf8))
    }

}

/// Holds a send inside the transport and ignores cancellation, so a test can prove what a late result does. Call
/// `release()` on every path, or the send never finishes.
final nonisolated class HoldingHTTPTransport: HTTPTransport {

    private let gate = Mutex<CheckedContinuation<Void, Never>?>(nil)
    private let cancelled = Mutex(false)
    private let arrivals: AsyncStream<Void>
    private let arrival: AsyncStream<Void>.Continuation

    init() {
        (self.arrivals, self.arrival) = AsyncStream.makeStream()
    }

    var wasCancelled: Bool {
        cancelled.withLock(\.self)
    }

    func waitForSend() async {
        for await _ in arrivals {
            return
        }
    }

    func release() {
        gate.withLock { continuation in
            continuation?.resume()
            continuation = nil
        }
    }

    @concurrent
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                gate.withLock { $0 = continuation }
                arrival.yield()
            }
        } onCancel: {
            cancelled.withLock { $0 = true }
        }
        return HTTPResponse(status: 200, headers: [:], body: Data())
    }

}
