//  CodeRequest.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

/// What both languages write, so they can't disagree about what a request sends.
nonisolated struct CodeRequest {

    let method: HTTPMethod
    let address: String
    let headers: [CodeHeader]

    init(_ resolved: ResolvedRequest) {
        self.method = resolved.method
        self.address = resolved.writtenAddress()
        self.headers = Self.manualHeaders(of: resolved)
    }

    /// `URLRequest` would join repeated cookies with a comma, which RFC 6265 reads as part of the first one's value.
    private static func manualHeaders(of resolved: ResolvedRequest) -> [CodeHeader] {
        var headers: [CodeHeader] = []

        for row in resolved.headers where row.isSent {
            let isCookie = row.key.caseInsensitiveCompare("Cookie") == .orderedSame
            if isCookie, let index = headers.firstIndex(where: { $0.isCookie }) {
                headers[index].value += "; \(row.value)"
            } else {
                headers.append(CodeHeader(name: row.key, value: row.value))
            }
        }

        return headers
    }

}

nonisolated struct CodeHeader {

    let name: String
    var value: String

    var isCookie: Bool {
        name.caseInsensitiveCompare("Cookie") == .orderedSame
    }

}
