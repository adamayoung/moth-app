//  SendPolicy.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

public struct SendPolicy: Sendable, Hashable {

    public static let standardCredentialHeaders: Set<String> = ["authorization", "cookie"]

    public var followsRedirects: Bool
    public var verifiesTLS: Bool
    /// Header names, compared ignoring case, that a redirect to another origin leaves behind.
    public var credentialHeaders: Set<String>

    public init(
        followsRedirects: Bool = true,
        verifiesTLS: Bool = true,
        credentialHeaders: Set<String> = Self.standardCredentialHeaders
    ) {
        self.followsRedirects = followsRedirects
        self.verifiesTLS = verifiesTLS
        self.credentialHeaders = credentialHeaders
    }

}
