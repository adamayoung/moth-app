//  RequestBody+Encoding.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated struct EncodedBody {

    var data: Data?
    var contentType: String?
    var omissions = BuildOmissions()
    var needsItsContentType = false
    var isFormWithNoRows = false

}

nonisolated extension RequestBody {

    var parts: Set<RequestPart> {
        switch self {
        case .urlEncoded(let rows): Set(rows.map { .row($0.id) })
        case .formData(let fields): Set(fields.map { .row($0.id) })
        case .none, .raw, .binary, .graphQL: [.body]
        }
    }

    func encoded(multipartBoundary: () -> String) -> EncodedBody {
        switch self {
        case .none:
            EncodedBody()
        case .raw(let content, let contentType):
            EncodedBody(data: Data(content.utf8), contentType: contentType.isEmpty ? nil : contentType)
        case .urlEncoded(let rows):
            EncodedBody(
                data: Data(rows.filter(\.isSent).map(\.percentEncodedPair).joined(separator: "&").utf8),
                contentType: "application/x-www-form-urlencoded",
                omissions: BuildOmissions(leftOut: Set(rows.filter { !$0.isSent }.map { .row($0.id) }))
            )
        case .formData(let fields):
            MultipartFormData(boundary: multipartBoundary(), fields: fields).encoded
        case .binary:
            EncodedBody(omissions: BuildOmissions(notices: [.unsupportedBody(.binary)], leftOut: parts))
        case .graphQL:
            EncodedBody(omissions: BuildOmissions(notices: [.unsupportedBody(.graphQL)], leftOut: parts))
        }
    }

}
