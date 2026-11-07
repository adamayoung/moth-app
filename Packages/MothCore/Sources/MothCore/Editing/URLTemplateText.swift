//  URLTemplateText.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// Splits by text, because `{{host}}/users` is no URL until it is resolved, and `URLComponents` refuses it.
public nonisolated struct URLTemplateText {

    public let address: String
    let query: String?
    let fragment: String?

    public init(_ text: String) {
        let aroundFragment = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .splitOutsideVariables(on: "#", maxSplits: 1)
        let aroundQuery = aroundFragment[0].splitOutsideVariables(on: "?", maxSplits: 1)
        self.address = String(aroundQuery[0])
        self.query = aroundQuery.count > 1 ? String(aroundQuery[1]) : nil
        self.fragment = aroundFragment.count > 1 ? String(aroundFragment[1]) : nil
    }

    public var queryPairs: [(key: String, value: String)] {
        guard let query else {
            return []
        }
        return query.splitOutsideVariables(on: "&").compactMap { piece in
            let pair = piece.splitOutsideVariables(on: "=", maxSplits: 1)
            guard !pair[0].isEmpty else {
                return nil
            }
            return (pair[0].decodedQueryText, pair.count > 1 ? pair[1].decodedQueryText : "")
        }
    }

    private var scheme: Substring {
        address.prefixMatch(of: /[A-Za-z][A-Za-z0-9+.\-]*:\/\//)?.output ?? ""
    }

    /// The segment after the scheme is the authority, however it is written: a port, or a `{{host}}`.
    private var authorityAndPath: [Substring] {
        address.dropFirst(scheme.count).split(separator: "/", omittingEmptySubsequences: false)
    }

    var pathVariableNames: [String] {
        var names: [String] = []
        for segment in authorityAndPath.dropFirst() {
            if let name = segment.pathVariableName, !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }

    func addressFillingPathVariables(from rows: [KeyValue]) -> String {
        let segments = authorityAndPath.enumerated().map { index, segment in
            guard index > 0 else {
                return Self.withUserinfoEscaped(segment)
            }
            guard let name = segment.pathVariableName, let row = rows.row(filling: name) else {
                return segment.urlEscaped
            }
            return row.value.urlDisplayEncoded
        }
        return scheme + segments.joined(separator: "/")
    }

    /// A host stays as written, because `URLComponents` gives it an IDNA form that percent-encoding wouldn't.
    private static func withUserinfoEscaped(_ authority: Substring) -> String {
        guard let separator = authority.lastIndex(of: "@") else {
            return String(authority)
        }
        return authority[..<separator].urlEscaped + authority[separator...]
    }

    public var withoutQuery: String {
        address + fragmentSuffix
    }

    func replacingQuery(with rows: [KeyValue]) -> String {
        address + Self.querySuffix(Self.displayPairs(of: rows)) + fragmentSuffix
    }

    func queryAndFragment(appending rows: [KeyValue], setting pair: LiteralQueryPair?) -> String {
        let written = (query?.splitOutsideVariables(on: "&") ?? [])
            .filter { $0.splitOutsideVariables(on: "=", maxSplits: 1)[0].decodedQueryText != pair?.name }
            .map(\.urlEscaped)
        let set = pair.map { ["\($0.name.urlDisplayEncoded)=\($0.value)"] } ?? []
        let pairs = written + Self.displayPairs(of: rows.filter { $0.key != pair?.name }) + set
        return Self.querySuffix(pairs.filter { !$0.isEmpty }) + (fragment.map { "#\($0.urlEscaped)" } ?? "")
    }

    private static func displayPairs(of rows: [KeyValue]) -> [String] {
        rows.filter(\.isSent).map(\.displayEncodedPair)
    }

    private static func querySuffix(_ pairs: [String]) -> String {
        pairs.isEmpty ? "" : "?\(pairs.joined(separator: "&"))"
    }

    private var fragmentSuffix: String {
        fragment.map { "#\($0)" } ?? ""
    }

}

private nonisolated extension StringProtocol where SubSequence == Substring {

    private var variableRanges: [Range<Index>] {
        ranges(of: VariableResolution.reference)
    }

    func splitOutsideVariables(on separator: Character, maxSplits: Int = .max) -> [Substring] {
        let variables = variableRanges
        var pieces: [Substring] = []
        var start = startIndex
        for index in indices where self[index] == separator && pieces.count < maxSplits {
            if !variables.contains(where: { $0.contains(index) }) {
                pieces.append(self[start ..< index])
                start = self.index(after: index)
            }
        }
        return pieces + [self[start...]]
    }

    func mapOutsideVariables(_ transform: (Substring) -> String) -> String {
        var result = ""
        var start = startIndex
        for variable in variableRanges {
            result += transform(self[start ..< variable.lowerBound])
            result += self[variable]
            start = variable.upperBound
        }
        return result + transform(self[start...])
    }

    /// A `+` is a space to a server, and `RequestBuilder` would send a row's `+` as `%2B`.
    var decodedQueryText: String {
        mapOutsideVariables { text in
            text.replacing("+", with: " ").removingPercentEncoding ?? String(text)
        }
    }

    /// Encodes what `URLComponents` would, for a URL it can't parse, so an escape stays one and a stray `%` doesn't.
    var urlEscaped: String {
        mapOutsideVariables { text in
            let escapes = text.replacing(/%(?![0-9A-Fa-f]{2})/.matchingSemantics(.unicodeScalar), with: "%25")
            return escapes.addingPercentEncoding(withAllowedCharacters: String.urlCharacters) ?? String(escapes)
        }
    }

}

private nonisolated extension String {

    static let urlCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=%"
    )

}

public nonisolated extension StringProtocol where SubSequence == Substring {

    var hasVariable: Bool {
        !variableRanges.isEmpty
    }

    var urlDisplayEncoded: String {
        mapOutsideVariables { String($0).percentEncoded }
    }

}
