//  String+HTTPSyntax.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension String {

    private static let tokenCharacters = CharacterSet(
        charactersIn: "!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    )

    /// RFC 9110's `token`. URLSession writes a method or header name to the wire as it is, line breaks included.
    var isHTTPToken: Bool {
        !isEmpty && unicodeScalars.allSatisfy(Self.tokenCharacters.contains)
    }

    /// URLRequest drops a value holding a line break, and URLSession strips what Latin-1 cannot hold.
    var isSendableHeaderValue: Bool {
        unicodeScalars.allSatisfy { scalar in
            scalar == "\t" || (0x20 ... 0x7E).contains(scalar.value) || (0x80 ... 0xFF).contains(scalar.value)
        }
    }

}
