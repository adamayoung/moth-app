//  FixtureFolderTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import Testing

struct FixtureFolderTests {

    @Test("The fixture folder holds the Apache-2.0 licence text")
    func holdsTheLicence() throws {
        let licence = try String(decoding: Fixture.data("LICENSE"), as: UTF8.self)

        #expect(licence.contains("Apache License"))
        #expect(licence.contains("Version 2.0, January 2004"))
    }

    @Test("The sources note names every fixture and each repository's copyright notice")
    func notesEveryFixture() throws {
        let sources = try String(decoding: Fixture.data("SOURCES.md"), as: UTF8.self)
        let fixtures = try fixturePaths()

        #expect(fixtures.count == 16)
        for fixture in fixtures {
            #expect(sources.contains(fixture), "SOURCES.md doesn't name \(fixture)")
        }
        #expect(sources.contains("Copyright 2016 Postdot Technologies, Inc"))
        #expect(sources.contains("Copyright 2018 Postman, Inc"))
        #expect(sources.contains("Copyright 2015 Postdot Technologies Pvt. Ltd."))
        #expect(sources.contains("Copyright 2017 Postdot Technologies Pvt. Ltd."))
        #expect(sources.contains("Copyright 2025 Postman, Inc."))
    }

    private func fixturePaths() throws -> [String] {
        let root = try Fixture.url("")
        let urls = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL]
        return (urls ?? [])
            .filter { $0.pathExtension == "json" }
            .map { $0.pathComponents.drop { $0 != "Fixtures" }.dropFirst().joined(separator: "/") }
    }

}
