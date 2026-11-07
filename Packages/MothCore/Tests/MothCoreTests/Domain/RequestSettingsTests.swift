//  RequestSettingsTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct RequestSettingsTests {

    @Test(
        "A timeout takes whole seconds from 1 to 3600",
        arguments: [("1", 1), ("60", 60), ("3600", 3600), (" 30 ", 30)]
    )
    func acceptsWholeSeconds(text: String, seconds: Int) {
        #expect(RequestSettings.timeout(fromText: text) == .seconds(seconds))
    }

    @Test("A timeout refuses anything else", arguments: ["0", "3601", "-5", "1.5", "abc", "", "1e3", "+5"])
    func refusesOtherText(text: String) {
        #expect(RequestSettings.timeout(fromText: text) == nil)
    }

    @Test("A timeout shows as whole seconds")
    func showsWholeSeconds() {
        #expect(RequestSettings.timeoutText(for: .seconds(60)) == "60")
        #expect(RequestSettings.timeoutText(for: .milliseconds(2500)) == "3")
    }

}
