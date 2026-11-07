//  OAuth2Token.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// Stored as JSON under the auth's `accessToken` reference, so its expiry needs no model field.
public nonisolated struct OAuth2Token: Sendable, Hashable, Codable {

    public enum State: Sendable, Hashable {

        case expires(Date)
        case noExpiry
        case expired

    }

    private static let renewalMargin: TimeInterval = 60

    public var value: String
    public var expiresAt: Date?

    public init(value: String, expiresAt: Date?) {
        self.value = value
        self.expiresAt = expiresAt
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
