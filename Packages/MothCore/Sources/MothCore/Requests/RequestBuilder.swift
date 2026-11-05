//  RequestBuilder.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct RequestBuilder: Sendable {

    private let multipartBoundary: @Sendable () -> String

    public init(multipartBoundary: @escaping @Sendable () -> String = { "moth-\(UUID().uuidString)" }) {
        self.multipartBoundary = multipartBoundary
    }

    @concurrent
    public func build(_ request: ResolvedRequest) async throws -> BuiltRequest {
        var urlRequest = try URLRequest(url: request.sendableURL())
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.settings.timeout.timeInterval

        for header in request.headers where header.isSent {
            urlRequest.addValue(header.value, forHTTPHeaderField: header.key)
        }

        let body = request.body.encoded(multipartBoundary: multipartBoundary)
        urlRequest.httpBody = body.data

        if let contentType = body.contentType, urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        return BuiltRequest(urlRequest: urlRequest, notices: body.notices)
    }

}
