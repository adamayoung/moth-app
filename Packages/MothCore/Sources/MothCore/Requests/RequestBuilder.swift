//  RequestBuilder.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct RequestBuilder: Sendable {

    /// URLSession fails a GET that has a body, and a HEAD with one announces a length and sends no bytes.
    private static let methodsWithoutBodies: Set<String> = ["GET", "HEAD"]

    private let multipartBoundary: @Sendable () -> String

    public init(multipartBoundary: @escaping @Sendable () -> String = { "moth-\(UUID().uuidString)" }) {
        self.multipartBoundary = multipartBoundary
    }

    @concurrent
    public func build(_ request: ResolvedRequest) async throws -> BuiltRequest {
        guard request.method.rawValue.isHTTPToken else {
            throw RequestBuildError.invalidMethod
        }

        var urlRequest = try URLRequest(url: request.sendableURL())
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.settings.timeout / .seconds(1)

        var notices = Self.applyHeaders(request.headers, to: &urlRequest)
        notices += applyBody(of: request, to: &urlRequest)

        try await request.authProvider?.apply(to: &urlRequest)

        if let authNotice = request.authNotice {
            notices.append(authNotice)
        }

        return BuiltRequest(urlRequest: urlRequest, notices: notices)
    }

    private static func applyHeaders(
        _ headers: [KeyValue],
        to urlRequest: inout URLRequest
    ) -> [RequestBuildNotice] {
        var notices: [RequestBuildNotice] = []

        for header in headers where header.isSent {
            guard header.key.isHTTPToken, header.value.isSendableHeaderValue else {
                notices.append(.unsendableHeader(name: header.key))
                continue
            }

            add(header, to: &urlRequest)
        }

        return notices
    }

    /// `addValue` joins with a comma, which RFC 6265 reads as part of the first cookie's value.
    private static func add(_ header: KeyValue, to urlRequest: inout URLRequest) {
        if
            header.key.caseInsensitiveCompare("Cookie") == .orderedSame,
            let cookies = urlRequest.value(forHTTPHeaderField: "Cookie") {
            urlRequest.setValue("\(cookies); \(header.value)", forHTTPHeaderField: "Cookie")
        } else {
            urlRequest.addValue(header.value, forHTTPHeaderField: header.key)
        }
    }

    private func applyBody(of request: ResolvedRequest, to urlRequest: inout URLRequest) -> [RequestBuildNotice] {
        let body = request.body.encoded(multipartBoundary: multipartBoundary)

        if body.data?.isEmpty == false, Self.methodsWithoutBodies.contains(request.method.rawValue.uppercased()) {
            return body.notices + [.bodyNotSent(method: request.method)]
        }

        urlRequest.httpBody = body.data

        guard let contentType = body.contentType else {
            return body.notices
        }

        guard urlRequest.value(forHTTPHeaderField: "Content-Type") == nil else {
            return body.needsItsContentType ? body.notices + [.formDataBoundaryNotDeclared] : body.notices
        }

        urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")

        return body.notices
    }

}
