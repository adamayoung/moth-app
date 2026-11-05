//  String+PercentEncoding.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension String {

    /// Spelled out because `CharacterSet.alphanumerics` holds non-ASCII letters, and
    /// `URLComponents`' percent-encoded setters trap on those.
    private static let unreservedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    var percentEncoded: String {
        addingPercentEncoding(withAllowedCharacters: Self.unreservedCharacters) ?? ""
    }

}
