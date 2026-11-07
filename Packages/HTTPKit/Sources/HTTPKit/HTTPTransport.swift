//  HTTPTransport.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public protocol HTTPTransport: Sendable {

    /// `cookies` supplies the request's cookies and keeps what the responses set, redirects included.
    @concurrent
    func send(_ request: URLRequest, cookies: any CookieJar?, policy: SendPolicy) async throws -> HTTPResponse

}

public extension HTTPTransport {

    @concurrent
    func send(_ request: URLRequest, cookies: any CookieJar?) async throws -> HTTPResponse {
        try await send(request, cookies: cookies, policy: SendPolicy())
    }

    @concurrent
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        try await send(request, cookies: nil, policy: SendPolicy())
    }

}
