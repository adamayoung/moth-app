//  ShellWords.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated enum ShellWordsError: Error, Equatable {

    case unclosedQuote

}

/// Reads text as a shell reads one command, and expands nothing: `$TOKEN` stays those six characters.
nonisolated struct ShellWords: Sendable, Equatable {

    let words: [String]
    /// What follows the command, from the operator or newline that ended it.
    let rest: String?

    init(_ text: String) throws {
        var scanner = ShellScanner(text)
        try scanner.scan()

        self.words = scanner.words
        self.rest = scanner.rest
    }

}

private nonisolated struct ShellScanner {

    private static let commandEnders: Set<Character> = ["|", "&", ";", "<", ">"]
    private static let doubleQuoteEscapable: Set<Character> = ["$", "`", "\"", "\\"]

    private let characters: [Character]
    private var position = 0
    private var word: String?
    private(set) var words: [String] = []

    var rest: String? {
        let text = String(characters[position...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    init(_ text: String) {
        self.characters = Array(text)
    }

    mutating func scan() throws {
        while let character = current {
            if character.isNewline, !words.isEmpty || word != nil {
                break
            }
            if Self.commandEnders.contains(character) {
                break
            }
            try consume(character)
        }
        finishWord()
    }

    private var current: Character? {
        characters.indices.contains(position) ? characters[position] : nil
    }

    private var next: Character? {
        characters.indices.contains(position + 1) ? characters[position + 1] : nil
    }

    private mutating func consume(_ character: Character) throws {
        switch character {
        case " ", "\t":
            finishWord()
            position += 1
        case _ where character.isNewline:
            position += 1
        case "#" where word == nil:
            skipComment()
        case "\\":
            consumeBackslash()
        case "'":
            try consumeSingleQuoted()
        case "\"":
            try consumeDoubleQuoted()
        case "$" where next == "'":
            position += 1
            try consumeANSIQuoted()
        default:
            append(String(character))
            position += 1
        }
    }

    private mutating func append(_ text: String) {
        word = (word ?? "") + text
    }

    private mutating func finishWord() {
        if let word {
            words.append(word)
        }
        word = nil
    }

    private mutating func skipComment() {
        while let character = current, !character.isNewline {
            position += 1
        }
    }

    private mutating func consumeBackslash() {
        position += 1
        guard let escaped = current else {
            append("\\")
            return
        }
        if !escaped.isNewline {
            append(String(escaped))
        }
        position += 1
    }

    private mutating func consumeSingleQuoted() throws {
        position += 1
        append("")
        while let character = current, character != "'" {
            append(String(character))
            position += 1
        }
        try closeQuote()
    }

    private mutating func consumeDoubleQuoted() throws {
        position += 1
        append("")
        while let character = current, character != "\"" {
            position += 1
            guard character == "\\", let escaped = current else {
                append(String(character))
                continue
            }
            if escaped.isNewline {
                position += 1
            } else if Self.doubleQuoteEscapable.contains(escaped) {
                append(String(escaped))
                position += 1
            } else {
                append("\\")
            }
        }
        try closeQuote()
    }

    /// Browsers' Copy as cURL writes this form, and Firefox escapes each UTF-16 unit, so `\u` can be half a pair.
    private mutating func consumeANSIQuoted() throws {
        position += 1
        var units: [UInt16] = []
        while let character = current, character != "'" {
            position += 1
            if character == "\\" {
                units += consumeANSIEscape()
            } else {
                units += String(character).utf16
            }
        }
        append(String(decoding: units, as: UTF16.self))
        try closeQuote()
    }

    private mutating func consumeANSIEscape() -> [UInt16] {
        guard let escaped = current else {
            return Array("\\".utf16)
        }
        position += 1

        switch escaped {
        case "x": return [UInt16(number(radix: 16, maxDigits: 2) ?? 0)]
        case "u": return [UInt16(number(radix: 16, maxDigits: 4) ?? 0)]
        case "U": return number(radix: 16, maxDigits: 8).flatMap(Unicode.Scalar.init)
            .map { Array(String($0).utf16) } ?? []
        case "0" ... "7":
            position -= 1
            return [UInt16(number(radix: 8, maxDigits: 3) ?? 0)]
        default:
            return Array((Self.ansiEscapes[escaped] ?? "\\\(escaped)").utf16)
        }
    }

    private static let ansiEscapes: [Character: String] = [
        "a": "\u{07}", "b": "\u{08}", "e": "\u{1B}", "E": "\u{1B}", "f": "\u{0C}", "n": "\n", "r": "\r", "t": "\t",
        "v": "\u{0B}", "\\": "\\", "'": "'", "\"": "\"", "?": "?"
    ]

    private mutating func number(radix: Int, maxDigits: Int) -> UInt32? {
        let start = position
        while position - start < maxDigits, let digit = current, digit.isHexDigit,
              digit.hexDigitValue.map({ $0 < radix }) == true {
            position += 1
        }
        return UInt32(String(characters[start ..< position]), radix: radix)
    }

    private mutating func closeQuote() throws {
        guard current != nil else {
            throw ShellWordsError.unclosedQuote
        }
        position += 1
    }

}
