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
    let basicCredentials: String?
    let body: CodeBody
    let notes: [String]

    init(_ resolved: ResolvedRequest) throws {
        let auth = CodeAuth(resolved.auth)
        var body = try CodeBody.Written(resolved.body)
        var notes = [auth.note].compactMap(\.self)

        if !resolved.method.sendsBody {
            if !body.content.isEmpty {
                let method = resolved.method.rawValue
                notes.append(String(localized: "CODE_NOTE_BODY_\(method)", bundle: .module))
            }
            body = CodeBody.Written(content: .none, contentType: nil)
        }

        var headers = Self.manualHeaders(of: resolved).filter { !$0.hasName(auth.headerName) }
        if let contentType = body.contentType, !headers.contains(where: \.isContentType) {
            headers.append(CodeHeader(name: "Content-Type", value: contentType))
        }
        if let header = auth.header {
            headers.append(header)
        }

        self.method = resolved.method
        self.address = resolved.writtenAddress(addingQuery: auth.queryPair)
        self.headers = headers
        self.basicCredentials = auth.basicCredentials
        self.body = body.content
        self.notes = notes
    }

    /// `URLRequest` would join repeated cookies with a comma, which RFC 6265 reads as part of the first one's value.
    private static func manualHeaders(of resolved: ResolvedRequest) -> [CodeHeader] {
        var headers: [CodeHeader] = []

        for row in resolved.headers where row.isSent {
            let header = CodeHeader(name: row.key, value: row.value)
            if header.isCookie, let index = headers.firstIndex(where: \.isCookie) {
                headers[index].value += "; \(row.value)"
            } else {
                headers.append(header)
            }
        }

        return headers
    }

}

nonisolated struct CodeHeader {

    let name: String
    var value: String

    var isCookie: Bool {
        hasName("Cookie")
    }

    var isContentType: Bool {
        hasName("Content-Type")
    }

    func hasName(_ other: String?) -> Bool {
        other.map { name.caseInsensitiveCompare($0) == .orderedSame } ?? false
    }

}
