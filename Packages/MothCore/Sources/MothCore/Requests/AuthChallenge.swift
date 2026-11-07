//  AuthChallenge.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// One challenge from a `WWW-Authenticate` value, with its parameter names lower-cased.
nonisolated struct AuthChallenge: Sendable, Hashable {

    let scheme: String
    var parameters: [String: String] = [:]

    /// URLSession joins a repeated header with commas, and a quoted parameter value can hold one too.
    static func all(in header: String) -> [AuthChallenge] {
        var scanner = ChallengeScanner(header)
        var challenges: [AuthChallenge] = []

        while let token = scanner.token() {
            if !challenges.isEmpty, scanner.skipEquals() {
                challenges[challenges.count - 1].parameters[token.lowercased()] = scanner.value()
            } else {
                challenges.append(AuthChallenge(scheme: token))
            }
        }

        return challenges
    }

    func isScheme(_ name: String) -> Bool {
        scheme.caseInsensitiveCompare(name) == .orderedSame
    }

}

private nonisolated struct ChallengeScanner {

    private let text: String
    private var index: String.Index

    init(_ text: String) {
        self.text = text
        self.index = text.startIndex
    }

    mutating func token() -> String? {
        skip { $0 == " " || $0 == "\t" || $0 == "," || $0 == "=" }
        let start = index
        skip { !Self.endsToken($0) }
        return start == index ? nil : String(text[start ..< index])
    }

    mutating func skipEquals() -> Bool {
        var probe = index
        while probe < text.endIndex, text[probe] == " " || text[probe] == "\t" {
            probe = text.index(after: probe)
        }
        guard probe < text.endIndex, text[probe] == "=" else {
            return false
        }
        index = text.index(after: probe)
        return true
    }

    mutating func value() -> String {
        skip { $0 == " " || $0 == "\t" }
        guard index < text.endIndex, text[index] == "\"" else {
            let start = index
            skip { !Self.endsValue($0) }
            return String(text[start ..< index])
        }
        return quotedString()
    }

    private mutating func quotedString() -> String {
        var value = ""
        index = text.index(after: index)
        while index < text.endIndex {
            let character = text[index]
            index = text.index(after: index)
            if character == "\"" {
                break
            }
            if character == "\\", index < text.endIndex {
                value.append(text[index])
                index = text.index(after: index)
            } else {
                value.append(character)
            }
        }
        return value
    }

    private mutating func skip(while matches: (Character) -> Bool) {
        while index < text.endIndex, matches(text[index]) {
            index = text.index(after: index)
        }
    }

    /// Unlike a token, a value can hold `=`, as base64 padding does in a nonce some servers send unquoted.
    private static func endsValue(_ character: Character) -> Bool {
        character == " " || character == "\t" || character == ","
    }

    private static func endsToken(_ character: Character) -> Bool {
        character == " " || character == "\t" || character == "," || character == "="
    }

}
