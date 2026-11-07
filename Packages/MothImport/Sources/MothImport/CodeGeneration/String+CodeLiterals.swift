//  String+CodeLiterals.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension String {

    /// Only `'` is special inside POSIX single quotes. Works on scalars, because `'` and a combining mark after it
    /// are one `Character`, which a replacement by `Character` would leave unescaped.
    var shellQuoted: String {
        let quoted = unicodeScalars.reduce(into: "") { quoted, scalar in
            if scalar == "'" {
                quoted += #"'\''"#
            } else {
                quoted.unicodeScalars.append(scalar)
            }
        }
        return "'\(quoted)'"
    }

    var swiftLiteral: String {
        "\"\(swiftEscaped)\""
    }

    var swiftEscaped: String {
        unicodeScalars.reduce(into: "") { escaped, scalar in
            switch scalar {
            case "\\": escaped += #"\\"#
            case "\"": escaped += #"\""#
            case "\n": escaped += #"\n"#
            case "\r": escaped += #"\r"#
            case "\t": escaped += #"\t"#
            default:
                if scalar.isInvisibleInSource {
                    escaped += #"\u{\#(String(scalar.value, radix: 16))}"#
                } else {
                    escaped.unicodeScalars.append(scalar)
                }
            }
        }
    }

}

private nonisolated extension Unicode.Scalar {

    /// Each of these can break a string literal, or reorder how the source reads.
    var isInvisibleInSource: Bool {
        switch properties.generalCategory {
        case .control, .format, .lineSeparator, .paragraphSeparator: true
        default: false
        }
    }

}
