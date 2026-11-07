//  DigestChallenge+Header.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

@testable import MothCore

extension DigestChallenge {

    static func first(in header: String) -> DigestChallenge? {
        first(in: AuthChallenge.all(in: header))
    }

}
