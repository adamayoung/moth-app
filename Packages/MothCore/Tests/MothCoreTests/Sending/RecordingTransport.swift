//  RecordingTransport.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Synchronization

final nonisolated class RecordingTransport: HTTPTransport {

    private let sent = Mutex<[URLRequest]>([])
    private let result: @Sendable () throws -> HTTPResponse

    init(result: @escaping @Sendable () throws -> HTTPResponse = {
        HTTPResponse(status: 200, headers: [:], body: Data())
    }) {
        self.result = result
    }

    var requests: [URLRequest] {
        sent.withLock(\.self)
    }

    @concurrent
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        sent.withLock { $0.append(request) }
        return try result()
    }

}
