//  HTTPMethodTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct HTTPMethodTests {

    @Test(
        "A standard method has its uppercase name",
        arguments: [
            (HTTPMethod.get, "GET"),
            (.post, "POST"),
            (.put, "PUT"),
            (.patch, "PATCH"),
            (.delete, "DELETE"),
            (.head, "HEAD"),
            (.options, "OPTIONS"),
            (.trace, "TRACE"),
            (.connect, "CONNECT")
        ]
    )
    func standardMethodName(method: HTTPMethod, name: String) {
        #expect(method.rawValue == name)
    }

    @Test("A custom method is kept exactly as written")
    func keepsACustomMethod() {
        let method = HTTPMethod(rawValue: "PROPFIND")

        #expect(method.rawValue == "PROPFIND")
    }

    @Test("A standard name is the standard method, so one method has one representation")
    func standardNameEqualsItsMember() {
        #expect(HTTPMethod(rawValue: "GET") == .get)
    }

    @Test("Methods are case-sensitive, so a lowercase name is a custom method")
    func lowercaseNameIsCustom() {
        let method = HTTPMethod(rawValue: "get")

        #expect(method != .get)
        #expect(method.rawValue == "get")
    }

    @Test("GET and HEAD send no body, in either case, and every other method does")
    func sendsBody() {
        #expect(!HTTPMethod.get.sendsBody)
        #expect(!HTTPMethod.head.sendsBody)
        #expect(!HTTPMethod(rawValue: "get").sendsBody)
        #expect(HTTPMethod.post.sendsBody)
        #expect(HTTPMethod(rawValue: "PROPFIND").sendsBody)
    }

}
