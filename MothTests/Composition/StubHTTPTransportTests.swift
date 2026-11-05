//  StubHTTPTransportTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import Moth
import Testing

struct StubHTTPTransportTests {

    @Test("A request to an unroutable host gets the fixed response, so nothing reached the network")
    func answersWithoutTheNetwork() async throws {
        let url = try #require(URL(string: "https://stub.invalid/"))

        let response = try await StubHTTPTransport().send(URLRequest(url: url))

        #expect(response.status == 200)
        #expect(response.value(forHeader: "Content-Type") == "application/json")
        #expect(response.body == Data("{}".utf8))
    }

}
