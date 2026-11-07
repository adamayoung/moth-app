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
    let redirections: [String]
    /// What follows the command, from the operator or newline that ended it.
    let rest: String?

    init(_ text: String) throws {
        var scanner = ShellScanner(text)
        try scanner.scan()

        self.words = scanner.words
        self.redirections = scanner.redirections
        self.rest = scanner.rest
    }

}

private nonisolated struct ShellScanner {

    private static let commandEnders: Set<Character> = ["|", "&", ";"]
    private static let redirectionStarters: Set<Character> = ["<", ">"]
    private static let redirectionOperators: Set<Character> = ["<", ">", "&", "|"]
    private static let doubleQuoteEscapable: Set<Character> = ["$", "`", "\"", "\\"]

    private let characters: [Character]
    private var position = 0
    private var word: String?
    private(set) var words: [String] = []
    private(set) var redirections: [String] = []

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
            if Self.redirectionStarters.contains(character) {
                try consumeRedirection()
                continue
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
        var extended = word.take() ?? ""
        extended += text
        word = extended
    }

    private mutating func finishWord() {
        if let word {
            words.append(word)
        }
        word = nil
    }

    /// A redirection sits anywhere in a command, so the words after it still count. The digits of `2>` aren't a word.
    private mutating func consumeRedirection() throws {
        if word?.allSatisfy(\.isNumber) == true {
            word = nil
        }
        finishWord()

        let start = position
        while let character = current, Self.redirectionOperators.contains(character) {
            position += 1
        }
        while current == " " || current == "\t" {
            position += 1
        }
        while let character = current, !character.isWhitespace, !Self.commandEnders.contains(character) {
            try consume(character)
        }
        word = nil
        redirections.append(String(characters[start ..< position]))
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

    private mutating func consumeANSIQuoted() throws {
        position += 1
        var text = ANSIText()
        while let character = current, character != "'" {
            position += 1
            if character == "\\" {
                consumeANSIEscape(into: &text)
            } else {
                text.append(String(character))
            }
        }
        append(text.finished())
        try closeQuote()
    }

    /// An escape with no digits stays literal, as it does in bash.
    private mutating func consumeANSIEscape(into text: inout ANSIText) {
        guard let escaped = current else {
            text.append("\\")
            return
        }
        position += 1

        switch escaped {
        case "x":
            if let value = number(radix: 16, maxDigits: 2) {
                text.append(byte: UInt8(truncatingIfNeeded: value))
            } else {
                text.append("\\x")
            }
        case "u":
            if let value = number(radix: 16, maxDigits: 4) {
                text.append(unit: UInt16(truncatingIfNeeded: value))
            } else {
                text.append("\\u")
            }
        case "U":
            text.append(number(radix: 16, maxDigits: 8).flatMap(Unicode.Scalar.init).map(String.init) ?? "\\U")
        case "0" ... "7":
            position -= 1
            text.append(byte: UInt8(truncatingIfNeeded: number(radix: 8, maxDigits: 3) ?? 0))
        default:
            text.append(Self.ansiEscapes[escaped] ?? "\\\(escaped)")
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

/// `\x` and octal escapes are bytes, and several can spell one UTF-8 character. Browsers' Copy as cURL writes this
/// quoting, and Firefox escapes each UTF-16 unit, so a `\u` can be half a pair.
private nonisolated struct ANSIText {

    private var units: [UInt16] = []
    private var bytes: [UInt8] = []

    mutating func append(_ text: String) {
        flushBytes()
        units += text.utf16
    }

    mutating func append(unit: UInt16) {
        flushBytes()
        units.append(unit)
    }

    mutating func append(byte: UInt8) {
        bytes.append(byte)
    }

    mutating func finished() -> String {
        flushBytes()
        return String(decoding: units, as: UTF16.self)
    }

    private mutating func flushBytes() {
        units += String(decoding: bytes, as: UTF8.self).utf16
        bytes = []
    }

}
