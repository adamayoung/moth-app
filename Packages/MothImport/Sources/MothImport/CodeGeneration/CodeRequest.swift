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

        let rows = resolved.headers.filter { $0.isSent && !CodeHeader($0).hasName(auth.headerName) }
        let writableRows = rows.filter(\.isWritableHeader)
        if writableRows.count < rows.count {
            notes.append(String(localized: "CODE_NOTE_HEADERS", bundle: .module))
        }

        var headers = Self.joiningCookies(of: writableRows)
        if let contentType = body.contentType, !headers.contains(where: \.isContentType) {
            headers.append(CodeHeader(name: "Content-Type", value: contentType))
        }
        if let header = auth.header {
            headers.append(header)
        }

        self.method = resolved.method
        self.address = resolved.writtenAddress(settingQuery: auth.queryPair)
        self.headers = headers
        self.basicCredentials = auth.basicCredentials
        self.body = body.content
        self.notes = notes
    }

    /// `URLRequest` would join repeated cookies with a comma, which RFC 6265 reads as part of the first one's value.
    private static func joiningCookies(of rows: [KeyValue]) -> [CodeHeader] {
        var headers: [CodeHeader] = []

        for row in rows {
            let header = CodeHeader(row)
            if header.isCookie, let index = headers.firstIndex(where: \.isCookie) {
                headers[index].value += "; \(row.value)"
            } else {
                headers.append(header)
            }
        }

        return headers
    }

}

private nonisolated extension KeyValue {

    /// As Send decides, except that filling in a `{{variable}}` left in the row may make it valid.
    var isWritableHeader: Bool {
        isSendableHeader || key.contains("{{") || value.contains("{{")
    }

}

nonisolated struct CodeHeader {

    let name: String
    var value: String

    init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    init(_ row: KeyValue) {
        self.init(name: row.key, value: row.value)
    }

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
