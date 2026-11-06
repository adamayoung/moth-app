//  RequestBody+Encoding.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated struct EncodedBody {

    var data: Data?
    var contentType: String?
    var notices: [RequestBuildNotice] = []
    var needsItsContentType = false

}

nonisolated extension RequestBody {

    func encoded(multipartBoundary: () -> String) -> EncodedBody {
        switch self {
        case .none:
            EncodedBody()
        case .raw(let content, let contentType):
            EncodedBody(data: Data(content.utf8), contentType: contentType.isEmpty ? nil : contentType)
        case .urlEncoded(let rows):
            EncodedBody(
                data: Data(rows.filter(\.isSent).map(\.percentEncodedPair).joined(separator: "&").utf8),
                contentType: "application/x-www-form-urlencoded"
            )
        case .formData(let fields):
            MultipartFormData(boundary: multipartBoundary(), fields: fields).encoded
        case .binary:
            EncodedBody(notices: [.unsupportedBody(.binary)])
        case .graphQL:
            EncodedBody(notices: [.unsupportedBody(.graphQL)])
        }
    }

}
