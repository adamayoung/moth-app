//  ScriptedTransport.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Synchronization

/// Answers each send with the next reply, and the last one again after that.
final nonisolated class ScriptedTransport: HTTPTransport {

    typealias Reply = @Sendable () async throws -> HTTPResponse

    private let sent = Mutex<[URLRequest]>([])
    private let jars = Mutex<[(any CookieJar)?]>([])
    private let replies: [Reply]
    private let arrival: AsyncStream<Int>.Continuation
    let arrivals: AsyncStream<Int>

    init(_ replies: [Reply]) {
        self.replies = replies
        (self.arrivals, self.arrival) = AsyncStream.makeStream()
    }

    convenience init(_ responses: HTTPResponse...) {
        self.init(responses.map { response in { response } })
    }

    var requests: [URLRequest] {
        sent.withLock(\.self)
    }

    var cookieJars: [(any CookieJar)?] {
        jars.withLock(\.self)
    }

    @concurrent
    func send(_ request: URLRequest, cookies: (any CookieJar)?) async throws -> HTTPResponse {
        jars.withLock { $0.append(cookies) }
        let count = sent.withLock {
            $0.append(request)
            return $0.count
        }
        arrival.yield(count)
        return try await replies[min(count, replies.count) - 1]()
    }

}
