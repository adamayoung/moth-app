//  OAuth2Token.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// Stored as JSON in the Keychain, under the auth's token reference, so its expiry needs no model field.
public nonisolated struct OAuth2Token: Sendable, Hashable, Codable {

    public enum State: Sendable, Hashable {

        case expires(Date)
        case noExpiry
        case expired

    }

    private static let renewalMargin: TimeInterval = 60

    public var value: String
    public var expiresAt: Date?
    /// The resolved Token URL, Client ID and Scope it was issued for, so another environment's token isn't sent.
    public var issuedFor: String?

    public init(value: String, expiresAt: Date?, issuedFor: String? = nil) {
        self.value = value
        self.expiresAt = expiresAt
        self.issuedFor = issuedFor
    }

    /// Text that isn't a record is a token as an import saved it, which carries no expiry.
    init(storedValue: String) {
        if let token = try? JSONDecoder().decode(Self.self, from: Data(storedValue.utf8)) {
            self = token
        } else {
            self.init(value: storedValue, expiresAt: nil)
        }
    }

    var storedValue: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(self)) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    public func state(at now: Date) -> State {
        guard let expiresAt else {
            return .noExpiry
        }
        return secondsLeft(at: now, until: expiresAt) > 0 ? .expires(expiresAt) : .expired
    }

    func needsRenewal(at now: Date) -> Bool {
        guard let expiresAt else {
            return false
        }
        return secondsLeft(at: now, until: expiresAt) <= Self.renewalMargin
    }

    private func secondsLeft(at now: Date, until expiresAt: Date) -> TimeInterval {
        expiresAt.timeIntervalSince(now)
    }

}
