//  RequestSettings.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated struct RequestSettings: Sendable, Hashable, Codable {

    public var timeout: Duration
    public var followsRedirects: Bool
    public var verifiesTLS: Bool

    public init(timeout: Duration = .seconds(60), followsRedirects: Bool = true, verifiesTLS: Bool = true) {
        self.timeout = timeout
        self.followsRedirects = followsRedirects
        self.verifiesTLS = verifiesTLS
    }

}
