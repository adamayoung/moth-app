//  CookieListTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

struct CookieListTests {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func cookie(
        _ name: String,
        _ value: String = "1",
        path: String = "/",
        expiresAt: Date? = nil,
        createdAt: Date? = nil
    ) -> Cookie {
        Cookie(
            name: name,
            value: value,
            domain: "example.com",
            isHostOnly: true,
            path: path,
            expiresAt: expiresAt,
            createdAt: createdAt ?? start
        )
    }

    private var url: URL {
        get throws {
            try #require(URL(string: "http://example.com/api/users"))
        }
    }

    @Test("A received cookie is kept and sent")
    func keepsACookie() throws {
        var list = CookieList()

        let change = list.receive([cookie("a")], at: start)

        #expect(change.saved == [cookie("a")])
        #expect(change.removed.isEmpty)
        #expect(try list.sending(to: url, at: start) == [cookie("a")])
    }

    @Test("A cookie with the same name, domain and path replaces the old one and keeps its creation time")
    func replaces() {
        var list = CookieList([cookie("a", "old")])
        let later = start.addingTimeInterval(60)

        let change = list.receive([cookie("a", "new", createdAt: later)], at: later)

        #expect(change.saved == [cookie("a", "new")])
        #expect(change.removed.isEmpty)
        #expect(list.cookies == [cookie("a", "new")])
    }

    @Test("The same name on another path is another cookie")
    func anotherPath() {
        var list = CookieList([cookie("a")])

        list.receive([cookie("a", path: "/api")], at: start)

        #expect(list.cookies.count == 2)
    }

    @Test("A received cookie that has already expired removes the one it replaces")
    func expiredRemoves() {
        var list = CookieList([cookie("a"), cookie("b")])

        let change = list.receive([cookie("a", expiresAt: start)], at: start)

        #expect(change.saved.isEmpty)
        #expect(change.removed == [cookie("a")])
        #expect(list.cookies == [cookie("b")])
    }

    @Test("An expired cookie with nothing to replace is dropped")
    func expiredWithNothingToReplace() {
        var list = CookieList()

        let change = list.receive([cookie("a", expiresAt: start)], at: start)

        #expect(change.saved.isEmpty)
        #expect(change.removed.isEmpty)
        #expect(list.cookies.isEmpty)
    }

    @Test("Cookies go out longest path first, then oldest first")
    func order() throws {
        let list = CookieList([
            cookie("root-new", createdAt: start.addingTimeInterval(2)),
            cookie("root-old", createdAt: start),
            cookie("api", path: "/api", createdAt: start.addingTimeInterval(5))
        ])

        #expect(try list.sending(to: url, at: start).map(\.name) == ["api", "root-old", "root-new"])
    }

    @Test("Removing expired cookies returns them")
    func removesExpired() {
        var list = CookieList([cookie("a", expiresAt: start), cookie("b")])

        let removed = list.removeExpired(at: start)

        #expect(removed == [cookie("a", expiresAt: start)])
        #expect(list.cookies == [cookie("b")])
    }

}
