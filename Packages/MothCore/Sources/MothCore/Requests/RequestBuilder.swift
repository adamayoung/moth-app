//  RequestBuilder.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct RequestBuilder: Sendable {

    /// URLSession fails a GET that has a body, and a HEAD with one announces a length and sends no bytes.
    private static let methodsWithoutBodies: Set<String> = ["GET", "HEAD"]

    private let multipartBoundary: @Sendable () -> String
    private let now: @Sendable () -> Date

    public init(
        multipartBoundary: @escaping @Sendable () -> String = { "moth-\(UUID().uuidString)" },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.multipartBoundary = multipartBoundary
        self.now = now
    }

    @concurrent
    public func build(_ request: ResolvedRequest) async throws -> BuiltRequest {
        guard request.method.rawValue.isHTTPToken else {
            throw RequestBuildError.invalidMethod
        }

        let address = try request.sendableAddress()
        var urlRequest = URLRequest(url: address.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.settings.timeout / .seconds(1)

        var omissions = address.omissions
        omissions.merge(Self.applyHeaders(request.headers, to: &urlRequest))
        omissions.merge(applyBody(of: request, to: &urlRequest))
        omissions.notices += emptiedKeyNotices(of: request, bodyWasLeftOff: omissions.leftOut.contains(.body))

        let authProvider = request.authProvider(signingAt: now())
        try await authProvider?.apply(to: &urlRequest)

        omissions.leftOut.formUnion(
            authProvider == nil ? [.auth] : Self.rowsReplacedByAuth(of: request)
        )

        if let authNotice = request.authNotice {
            omissions.notices.append(authNotice)
        }

        return BuiltRequest(
            urlRequest: urlRequest,
            notices: omissions.notices,
            unresolved: request.unresolved(outside: omissions.leftOut)
        )
    }

    private static func rowsReplacedByAuth(of request: ResolvedRequest) -> Set<RequestPart> {
        let replaced = request.headersReplacedByAuth

        return Set(request.headers.filter { replaced.contains($0.key.lowercased()) }.map { .row($0.id) })
    }

    private func emptiedKeyNotices(of request: ResolvedRequest, bodyWasLeftOff: Bool) -> [RequestBuildNotice] {
        let headers = request.headers.compactMap { request.emptiedKeys[$0.id] }
        let queryParameters = request.queryParameters.compactMap { request.emptiedKeys[$0.id] }
        let fields = bodyWasLeftOff ? [] : request.body.rowIDs.compactMap { request.emptiedKeys[$0] }

        return headers.map { .emptyHeaderName(name: $0) }
            + queryParameters.map { .emptyQueryParameterName(name: $0) }
            + fields.map { .emptyFieldName(name: $0) }
    }

    private static func applyHeaders(
        _ headers: [KeyValue],
        to urlRequest: inout URLRequest
    ) -> BuildOmissions {
        var omissions = BuildOmissions()

        for header in headers {
            guard header.isSent else {
                omissions.leftOut.insert(.row(header.id))
                continue
            }

            guard header.key.isHTTPToken, header.value.isSendableHeaderValue else {
                omissions.notices.append(.unsendableHeader(name: header.key))
                omissions.leftOut.insert(.row(header.id))
                continue
            }

            add(header, to: &urlRequest)
        }

        return omissions
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

    private func applyBody(of request: ResolvedRequest, to urlRequest: inout URLRequest) -> BuildOmissions {
        let body = request.body.encoded(multipartBoundary: multipartBoundary)
        var omissions = body.omissions

        if body.data?.isEmpty == false, Self.methodsWithoutBodies.contains(request.method.rawValue.uppercased()) {
            if !body.isFormWithNoRows {
                omissions.notices.append(.bodyNotSent(method: request.method))
                omissions.leftOut = request.body.parts
            }
            return omissions
        }

        urlRequest.httpBody = body.data

        guard let contentType = body.contentType else {
            return omissions
        }

        guard urlRequest.value(forHTTPHeaderField: "Content-Type") == nil else {
            if body.needsItsContentType {
                omissions.notices.append(.formDataBoundaryNotDeclared)
            }
            omissions.leftOut.insert(.bodyContentType)
            return omissions
        }

        urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")

        return omissions
    }

}
