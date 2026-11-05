//  StubHTTPTransport.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

final nonisolated class StubHTTPTransport: HTTPTransport {

    @concurrent
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        HTTPResponse(status: 200, headers: ["Content-Type": "application/json"], body: Data("{}".utf8))
    }

}
