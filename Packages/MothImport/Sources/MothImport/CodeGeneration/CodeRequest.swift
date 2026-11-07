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

        let manualHeaders = resolved.headers.filter(\.isSent).map(CodeHeader.init)
            .filter { !$0.hasName(auth.headerName) }
        let authHeaders = [auth.header].compactMap(\.self)
        if !(manualHeaders + authHeaders).allSatisfy(\.isWritable) {
            notes.append(String(localized: "CODE_NOTE_HEADERS", bundle: .module))
        }

        var headers = Self.joiningCookies(of: manualHeaders.filter(\.isWritable))
        if let contentType = body.contentType, !headers.contains(where: \.isContentType) {
            headers.append(CodeHeader(name: "Content-Type", value: contentType))
        }
        headers += authHeaders.filter(\.isWritable)

        self.method = resolved.method
        self.address = resolved.writtenAddress(settingQuery: auth.queryPair)
        self.headers = headers
        self.basicCredentials = auth.basicCredentials
        self.body = body.content
        self.notes = notes
    }

    /// `URLRequest` would join repeated cookies with a comma, which RFC 6265 reads as part of the first one's value.
    private static func joiningCookies(of headers: [CodeHeader]) -> [CodeHeader] {
        var joined: [CodeHeader] = []

        for header in headers {
            if header.isCookie, let index = joined.firstIndex(where: \.isCookie) {
                joined[index].value += "; \(header.value)"
            } else {
                joined.append(header)
            }
        }

        return joined
    }

}

nonisolated struct CodeHeader {

    let name: String
    var value: String

    /// As Send decides, except that filling in a `{{variable}}` may make a field valid. It can't remove a line break,
    /// which cURL would send as a second header, or a leading `@`, which cURL reads as a file.
    var isWritable: Bool {
        let hasLineBreak = "\(name)\(value)".unicodeScalars.contains { $0 == "\r" || $0 == "\n" }
        let canBecomeValid = !hasLineBreak && !name.hasPrefix("@")
        return (name.isHTTPToken || (canBecomeValid && name.hasVariable))
            && (value.isSendableHeaderValue || (canBecomeValid && value.hasVariable))
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

private nonisolated extension CodeHeader {

    init(_ row: KeyValue) {
        self.init(name: row.key, value: row.value)
    }

}
