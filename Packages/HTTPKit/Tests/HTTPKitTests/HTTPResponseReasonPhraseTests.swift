//  HTTPResponseReasonPhraseTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

struct HTTPResponseReasonPhraseTests {

    @Test(
        "A standard status has its RFC 9110 phrase",
        arguments: [
            (200, "OK"),
            (201, "Created"),
            (204, "No Content"),
            (301, "Moved Permanently"),
            (304, "Not Modified"),
            (400, "Bad Request"),
            (401, "Unauthorized"),
            (404, "Not Found"),
            (418, "I'm a Teapot"),
            (429, "Too Many Requests"),
            (500, "Internal Server Error"),
            (503, "Service Unavailable")
        ]
    )
    func standardStatus(status: Int, phrase: String) {
        #expect(HTTPResponse(status: status, headers: [:], body: Data()).reasonPhrase == phrase)
    }

    @Test("An unregistered status has no phrase")
    func unknownStatus() {
        #expect(HTTPResponse(status: 299, headers: [:], body: Data()).reasonPhrase == nil)
    }

}
