//  RequestSettings.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct RequestSettings: Sendable, Hashable, Codable {

    public var timeout: Duration
    public var followsRedirects: Bool
    public var verifiesTLS: Bool

    public init(timeout: Duration = .seconds(60), followsRedirects: Bool = true, verifiesTLS: Bool = true) {
        self.timeout = timeout
        self.followsRedirects = followsRedirects
        self.verifiesTLS = verifiesTLS
    }

    public static let timeoutRange = 1 ... 3600

    /// Digits only, because `Int` would also take a sign.
    public static func timeout(fromText text: String) -> Duration? {
        let digits = text.trimmingCharacters(in: .whitespaces)
        guard
            digits.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains),
            let seconds = Int(digits),
            timeoutRange.contains(seconds)
        else {
            return nil
        }
        return .seconds(seconds)
    }

    public static func timeoutText(for timeout: Duration) -> String {
        String(Int((timeout / .seconds(1)).rounded()))
    }

}
