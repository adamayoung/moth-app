//  CurlMapper.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

nonisolated struct CurlMapper {

    private static let formContentType = "application/x-www-form-urlencoded"

    private(set) var pendingSecrets: [PendingSecret] = []

    mutating func request(_ command: CurlCommand) -> Request {
        let (address, userinfo) = Self.splitUserinfo(command.urls[0])
        let url = URLTemplateText(address)
        let dataText = command.dataParts.joined(separator: "&")
        let dataRows = command.movesDataToQuery ? Self.rows(fromFormText: dataText) : []
        let queryRows = url.queryPairs.map { KeyValue(key: $0.key, value: $0.value) } + dataRows

        let method = Self.method(of: command)
        let headers = Self.headers(of: command)
        let headerRows = headers.filter { CurlCredential($0) == nil && !Self.hidesBoundary($0, in: command) }

        return Request(
            name: "\(method.rawValue) \(Self.path(of: url.address))",
            method: method,
            urlTemplate: queryRows.isEmpty ? address : url.withoutQuery,
            queryParameters: queryRows,
            headers: headerRows,
            body: Self.body(of: command, text: dataText, headers: headers),
            auth: auth(headers: headers, keptRows: headerRows, user: command.user, userinfo: userinfo),
            settings: RequestSettings(followsRedirects: command.followsRedirects, verifiesTLS: command.verifiesTLS)
        )
    }

    /// A header wins, as in curl. A kept `Authorization` row needs `.none`, because any provider would replace it.
    private mutating func auth(
        headers: [KeyValue],
        keptRows: [KeyValue],
        user: String?,
        userinfo: CurlCredential?
    ) -> Auth {
        if let credential = headers.lazy.compactMap(CurlCredential.init).first {
            return auth(credential)
        }
        if keptRows.contains(named: "Authorization") {
            return .none
        }
        return (user.map(CurlCredential.init) ?? userinfo).map { auth($0) } ?? .inherit
    }

    private mutating func auth(_ credential: CurlCredential) -> Auth {
        switch credential {
        case .basic(let username, let password):
            let reference = SecretReference()
            pendingSecrets.append(PendingSecret(reference: reference, value: password))
            return .basic(BasicAuth(username: username, password: reference))
        case .bearer(let token):
            let reference = SecretReference()
            pendingSecrets.append(PendingSecret(reference: reference, value: token))
            return .bearer(BearerAuth(token: reference))
        }
    }

    /// curl adds its boundary to this header. `RequestBuilder` can't, so a kept row would hide the one the body uses.
    private static func hidesBoundary(_ header: KeyValue, in command: CurlCommand) -> Bool {
        !command.formFields.isEmpty && header.hasName("Content-Type")
    }

    private static func method(of command: CurlCommand) -> HTTPMethod {
        if let method = command.method {
            return HTTPMethod(rawValue: method)
        }
        return !command.movesDataToQuery && (command.hasData || command.hasForm) ? .post : .get
    }

    private static func splitUserinfo(_ url: String) -> (address: String, credential: CurlCredential?) {
        guard let match = url.prefixMatch(of: /(?<scheme>[A-Za-z][A-Za-z0-9+.\-]*:\/\/)?(?<userinfo>[^\/?#]*)@/) else {
            return (url, nil)
        }
        let address = String((match.scheme ?? "") + url[match.range.upperBound...])
        return (address, CurlCredential(userinfo: match.userinfo))
    }

    private static func path(of address: String) -> String {
        let afterScheme = address.trimmingPrefix(/[A-Za-z][A-Za-z0-9+.\-]*:\/\//)
        return afterScheme.firstIndex(of: "/").map { String(afterScheme[$0...]) } ?? "/"
    }

    /// A header wins over its flag, because curl's generated header gives way to a custom one.
    private static func headers(of command: CurlCommand) -> [KeyValue] {
        var headers = command.headers
        let named: [(String, String?)] = [("User-Agent", command.userAgent), ("Referer", command.referer)]
        for case (let name, let value?) in named where !headers.contains(named: name) {
            headers.append(KeyValue(key: name, value: value))
        }
        if !headers.contains(named: "Cookie") {
            headers += command.cookies.map { KeyValue(key: "Cookie", value: $0) }
        }
        return headers
    }

    private static func body(of command: CurlCommand, text: String, headers: [KeyValue]) -> RequestBody {
        if !command.formFields.isEmpty {
            return .formData(command.formFields)
        }
        guard !command.movesDataToQuery, !text.isEmpty else {
            return .none
        }

        let contentType = headers.last { $0.hasName("Content-Type") }?.value ?? formContentType
        if contentType.lowercased().hasPrefix(formContentType), isFormText(text) {
            return .urlEncoded(rows(fromFormText: text))
        }
        return .raw(content: text, contentType: contentType)
    }

    /// Only text that rows can send back unchanged: an escape that isn't UTF-8 can't be decoded, and a template trims.
    private static func isFormText(_ text: String) -> Bool {
        text.last?.isWhitespace != true && text.split(separator: "&", omittingEmptySubsequences: false).allSatisfy {
            $0.wholeMatch(of: /[\w.~%\[\]\-]+=.*/) != nil && $0.removingPercentEncoding != nil
        }
    }

    /// Decoded as a query is, because `RequestBuilder` encodes rows. A `#` here is text, not a fragment.
    private static func rows(fromFormText text: String) -> [KeyValue] {
        URLTemplateText("?\(text.replacing("#", with: "%23"))").queryPairs
            .map { KeyValue(key: $0.key, value: $0.value) }
    }

}

private nonisolated enum CurlCredential: Equatable {

    case basic(username: String, password: String)
    case bearer(token: String)

    init(user: String) {
        let parts = user.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        self = .basic(username: String(parts[0]), password: parts.count > 1 ? String(parts[1]) : "")
    }

    /// Splits before decoding, so an encoded colon stays in the name.
    init?(userinfo: Substring) {
        guard !userinfo.isEmpty else {
            return nil
        }
        let parts = userinfo.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .map { $0.removingPercentEncoding ?? String($0) }
        self = .basic(username: parts[0], password: parts.count > 1 ? parts[1] : "")
    }

    /// Nil for what stays a header: any other name or scheme, and a Basic value that doesn't decode to `user:password`.
    init?(_ header: KeyValue) {
        let parts = header.value.split(whereSeparator: \.isWhitespace)
        guard header.hasName("Authorization"), parts.count == 2 else {
            return nil
        }

        switch parts[0].lowercased() {
        case "bearer":
            self = .bearer(token: String(parts[1]))
        case "basic":
            guard
                let decoded = Data(base64Encoded: String(parts[1])).flatMap({ String(bytes: $0, encoding: .utf8) }),
                decoded.contains(":")
            else {
                return nil
            }
            self.init(user: decoded)
        default:
            return nil
        }
    }

}

private nonisolated extension KeyValue {

    func hasName(_ name: String) -> Bool {
        key.caseInsensitiveCompare(name) == .orderedSame
    }

}

private nonisolated extension [KeyValue] {

    func contains(named name: String) -> Bool {
        contains { $0.hasName(name) }
    }

}
