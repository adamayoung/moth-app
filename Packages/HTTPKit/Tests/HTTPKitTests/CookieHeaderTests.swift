//  CookieHeaderTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

struct CookieHeaderTests {

    private func jar(_ pairs: (String, String)...) -> [Cookie] {
        pairs.map { name, value in
            Cookie(
                name: name,
                value: value,
                domain: "example.com",
                isHostOnly: true,
                path: "/",
                expiresAt: nil,
                createdAt: .distantPast
            )
        }
    }

    @Test("With no manual header and no cookies there is no header")
    func nothing() {
        #expect(CookieHeader.merging(manual: nil, jar: []) == nil)
        #expect(CookieHeader.merging(manual: "", jar: []) == nil)
    }

    @Test("A manual header alone goes as written")
    func manualOnly() {
        #expect(CookieHeader.merging(manual: "a=1; b=2", jar: []) == "a=1; b=2")
    }

    @Test("Jar cookies alone are joined with a semicolon and a space")
    func jarOnly() {
        #expect(CookieHeader.merging(manual: nil, jar: jar(("a", "1"), ("b", "2"))) == "a=1; b=2")
    }

    @Test("Jar cookies follow the manual header")
    func joined() {
        #expect(CookieHeader.merging(manual: "m=0", jar: jar(("a", "1"))) == "m=0; a=1")
    }

    @Test("A manual header's trailing semicolon leaves no empty cookie between it and the jar's")
    func trailingSemicolon() {
        #expect(CookieHeader.merging(manual: "a=1; ", jar: jar(("b", "2"))) == "a=1; b=2")
        #expect(CookieHeader.merging(manual: "a=1;", jar: []) == "a=1")
    }

    @Test("A manual cookie wins over a jar cookie of the same name")
    func manualWins() {
        #expect(CookieHeader.merging(manual: "a=mine; b=2", jar: jar(("a", "jar"), ("c", "3"))) == "a=mine; b=2; c=3")
    }

}
