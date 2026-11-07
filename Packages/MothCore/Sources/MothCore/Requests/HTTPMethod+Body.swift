//  HTTPMethod+Body.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated extension HTTPMethod {

    /// URLSession fails a GET that has a body, and a HEAD with one announces a length and sends no bytes.
    var sendsBody: Bool {
        !["GET", "HEAD"].contains(rawValue.uppercased())
    }

}
