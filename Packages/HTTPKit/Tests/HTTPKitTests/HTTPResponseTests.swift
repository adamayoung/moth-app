//  HTTPResponseTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

struct HTTPResponseTests {

    private let response = HTTPResponse(status: 200, headers: ["x-request-id": "abc"], body: Data())

    @Test("A header is found whatever the case of its name")
    func findsAHeaderInAnyCase() {
        #expect(response.value(forHeader: "X-Request-ID") == "abc")
    }

    @Test("A header that is absent returns nothing")
    func returnsNothingForAnAbsentHeader() {
        #expect(response.value(forHeader: "ETag") == nil)
    }

}
