//  OAuth2TokenTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import Testing

struct OAuth2TokenTests {

    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func token(expiringIn seconds: TimeInterval?) -> OAuth2Token {
        OAuth2Token(value: "abc", expiresAt: seconds.map { now.addingTimeInterval($0) })
    }

    @Test("A token with time left reports when it expires")
    func validTokenReportsItsExpiry() {
        let token = Self.token(expiringIn: 3540)

        #expect(token.state(at: Self.now) == .expires(Self.now.addingTimeInterval(3540)))
    }

    @Test("A token past its expiry is expired", arguments: [0.0, -1.0])
    func pastExpiryIsExpired(secondsLeft: TimeInterval) {
        #expect(Self.token(expiringIn: secondsLeft).state(at: Self.now) == .expired)
    }

    @Test("A token with no expiry never expires")
    func noExpiry() {
        let token = Self.token(expiringIn: nil)

        #expect(token.state(at: Self.now.addingTimeInterval(10 * 365 * 86400)) == .noExpiry)
        #expect(!token.needsRenewal(at: Self.now.addingTimeInterval(10 * 365 * 86400)))
    }

    @Test("A token is renewed once it has 60 seconds or less left", arguments: [
        (61.0, false),
        (60.0, true),
        (0.0, true),
        (-30.0, true)
    ])
    func renewalEdge(secondsLeft: TimeInterval, isRenewed: Bool) {
        #expect(Self.token(expiringIn: secondsLeft).needsRenewal(at: Self.now) == isRenewed)
    }

    @Test("A stored token reads back with its expiry")
    func storedRoundTrip() {
        let token = Self.token(expiringIn: 3600)

        #expect(OAuth2Token(storedValue: token.storedValue) == token)
        #expect(OAuth2Token(storedValue: Self.token(expiringIn: nil).storedValue) == Self.token(expiringIn: nil))
    }

    @Test("A stored value that isn't a token record is a token with no expiry, as an import saves one")
    func rawValueHasNoExpiry() {
        #expect(OAuth2Token(storedValue: "imported-token") == OAuth2Token(value: "imported-token", expiresAt: nil))
    }

}
