//  JSONReindenter.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// Lays out the text the server sent, because `JSONSerialization` output loses key order and rewrites numbers, and an
/// API client has to show what came back.
nonisolated struct JSONReindenter {

    private enum Byte {

        static let quote = UInt8(ascii: "\"")
        static let backslash = UInt8(ascii: "\\")
        static let openBrace = UInt8(ascii: "{")
        static let closeBrace = UInt8(ascii: "}")
        static let openBracket = UInt8(ascii: "[")
        static let closeBracket = UInt8(ascii: "]")
        static let comma = UInt8(ascii: ",")
        static let colon = UInt8(ascii: ":")
        static let space = UInt8(ascii: " ")
        static let newline = UInt8(ascii: "\n")
        static let whitespace: Set<UInt8> = [space, newline, UInt8(ascii: "\t"), UInt8(ascii: "\r")]

    }

    private var output: [UInt8] = []
    private var depth = 0
    private var isInString = false
    private var isEscaped = false

    /// Nil for anything that isn't JSON. Everything after this check can rely on the text being well formed.
    static func reindented(_ text: String) -> String? {
        let json = Array(text.utf8)
        guard (try? JSONSerialization.jsonObject(with: Data(json), options: .fragmentsAllowed)) != nil else {
            return nil
        }
        var reindenter = JSONReindenter()
        reindenter.output.reserveCapacity(json.count * 2)
        reindenter.lay(out: json)
        return String(bytes: reindenter.output, encoding: .utf8)
    }

    private mutating func lay(out json: [UInt8]) {
        var index = json.startIndex
        while index < json.endIndex {
            let byte = json[index]
            index += 1
            if isInString {
                continueString(with: byte)
            } else if byte == Byte.openBrace || byte == Byte.openBracket {
                index = open(byte, in: json, after: index)
            } else {
                layOutToken(byte)
            }
        }
    }

    private mutating func continueString(with byte: UInt8) {
        output.append(byte)
        if isEscaped {
            isEscaped = false
        } else if byte == Byte.backslash {
            isEscaped = true
        } else if byte == Byte.quote {
            isInString = false
        }
    }

    /// Returns where to carry on from, which skips the closer of an empty container.
    private mutating func open(_ byte: UInt8, in json: [UInt8], after index: Int) -> Int {
        output.append(byte)
        let next = json[index...].firstIndex { !Byte.whitespace.contains($0) } ?? index
        if json[next] == Byte.closeBrace || json[next] == Byte.closeBracket {
            output.append(json[next])
            return next + 1
        }
        depth += 1
        startLine()
        return index
    }

    private mutating func layOutToken(_ byte: UInt8) {
        switch byte {
        case Byte.quote:
            output.append(byte)
            isInString = true
        case Byte.closeBrace, Byte.closeBracket:
            depth -= 1
            startLine()
            output.append(byte)
        case Byte.comma:
            output.append(byte)
            startLine()
        case Byte.colon:
            output.append(byte)
            output.append(Byte.space)
        case _ where Byte.whitespace.contains(byte):
            break
        default:
            output.append(byte)
        }
    }

    private mutating func startLine() {
        output.append(Byte.newline)
        output.append(contentsOf: repeatElement(Byte.space, count: depth * 2))
    }

}
