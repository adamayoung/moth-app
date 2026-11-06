//  URLTemplateText.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// Splits by text, because `{{host}}/users` is no URL until it is resolved, and `URLComponents` refuses it.
nonisolated struct URLTemplateText {

    let address: String
    let query: String?
    let fragment: String?

    init(_ text: String) {
        let aroundFragment = text.splitOutsideVariables(on: "#", maxSplits: 1)
        let aroundQuery = aroundFragment[0].splitOutsideVariables(on: "?", maxSplits: 1)
        self.address = String(aroundQuery[0])
        self.query = aroundQuery.count > 1 ? String(aroundQuery[1]) : nil
        self.fragment = aroundFragment.count > 1 ? String(aroundFragment[1]) : nil
    }

    var queryPairs: [(key: String, value: String)] {
        guard let query else {
            return []
        }
        return query.splitOutsideVariables(on: "&").compactMap { piece in
            let pair = piece.splitOutsideVariables(on: "=", maxSplits: 1)
            guard !pair[0].isEmpty else {
                return nil
            }
            return (pair[0].decodedOutsideVariables, pair.count > 1 ? pair[1].decodedOutsideVariables : "")
        }
    }

    /// The segment after the scheme is the authority, however it is written: a port, or a `{{host}}`.
    var pathVariableNames: [String] {
        let withoutScheme = address.trimmingPrefix(/[A-Za-z][A-Za-z0-9+.\-]*:\/\//)
        var names: [String] = []
        for segment in withoutScheme.split(separator: "/", omittingEmptySubsequences: false).dropFirst() {
            if let name = segment.pathVariableName, !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }

    var withoutQuery: String {
        address + fragmentSuffix
    }

    func replacingQuery(with rows: [KeyValue]) -> String {
        let pairs = rows.filter(\.isSent).map { "\($0.key.urlDisplayEncoded)=\($0.value.urlDisplayEncoded)" }
        let query = pairs.isEmpty ? "" : "?\(pairs.joined(separator: "&"))"
        return address + query + fragmentSuffix
    }

    private var fragmentSuffix: String {
        fragment.map { "#\($0)" } ?? ""
    }

}

private nonisolated extension StringProtocol where SubSequence == Substring {

    /// `mapOutsideVariables` spares the same text that `VariableResolution` reads as a reference.
    private var variableRanges: [Range<Index>] {
        ranges(of: /\{\{[^{}]*\}\}/)
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

    var decodedOutsideVariables: String {
        mapOutsideVariables { $0.removingPercentEncoding ?? String($0) }
    }

    var urlDisplayEncoded: String {
        mapOutsideVariables { String($0).percentEncoded }
    }

}
