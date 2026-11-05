//  URLSessionHTTPTransport.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public struct URLSessionHTTPTransport: HTTPTransport {

    public let session: URLSession

    public init(session: URLSession) {
        self.session = session
    }

    @concurrent
    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (body, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPTransportError.notHTTP
        }

        return HTTPResponse(status: httpResponse.statusCode, headers: Self.headers(of: httpResponse), body: body)
    }

    private static func headers(of response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (name, value) in response.allHeaderFields {
            if let name = name as? String, let value = value as? String {
                headers[name] = value
            }
        }
        return headers
    }

}
