//  CurlImportIgnoredTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct CurlImportIgnoredTests {

    @Test(
        "A flag Moth doesn't read is listed",
        arguments: [
            ("curl -s https://a.example", ["-s"]),
            ("curl --verbose https://a.example", ["--verbose"]),
            ("curl --no-such-flag https://a.example", ["--no-such-flag"]),
            ("curl -I https://a.example", ["-I"]),
            ("curl --digest https://a.example", ["--digest"]),
            ("curl --json '{}' https://a.example", ["--json"]),
            ("curl --oauth2-bearer secret https://a.example", ["--oauth2-bearer"])
        ]
    )
    func listsFlags(text: String, ignored: [String]) async throws {
        #expect(try await CurlImportTesting.ignored(text) == ignored)
    }

    @Test("A flag given twice is listed once, in the order it first came")
    func listsAFlagOnce() async throws {
        #expect(try await CurlImportTesting.ignored("curl -v -s -v https://a.example") == ["-v", "-s"])
    }

    @Test(
        "--data @file reads no file: the body stays empty and it is listed",
        arguments: [
            ("curl --data @body.json https://a.example", "--data @body.json"),
            ("curl -d @body.json https://a.example", "-d @body.json"),
            ("curl --data-ascii @body.json https://a.example", "--data-ascii @body.json"),
            ("curl --data-binary @body.json https://a.example", "--data-binary @body.json"),
            ("curl --data-urlencode @body.txt https://a.example", "--data-urlencode @body.txt"),
            ("curl --data-urlencode name@body.txt https://a.example", "--data-urlencode name@body.txt")
        ]
    )
    func listsDataFiles(text: String, ignored: String) async throws {
        let result = try await CurlImportTesting.importing(text)

        #expect(result.ignored == [ignored])
        #expect(result.request.body == .none)
        #expect(result.request.method == .post)
    }

    @Test(
        "Any other flag that names a file is listed, and adds nothing to the request",
        arguments: [
            ("curl -H @headers.txt https://a.example", "-H @headers.txt"),
            ("curl -b cookies.txt https://a.example", "-b cookies.txt"),
            ("curl --cookie cookies.txt https://a.example", "--cookie cookies.txt")
        ]
    )
    func listsOtherFiles(text: String, ignored: String) async throws {
        let result = try await CurlImportTesting.importing(text)

        #expect(result.ignored == [ignored])
        #expect(result.request.headers.isEmpty)
    }

    @Test("-F with text from a file is listed, and keeps no field")
    func listsFormTextFiles() async throws {
        let result = try await CurlImportTesting.importing("curl -F 'a=<body.txt' https://a.example")

        #expect(result.ignored == ["-F a=<body.txt"])
        #expect(result.request.body == .none)
    }

    @Test("A header with a name and no value tells curl to drop it, so it is listed and adds no row")
    func listsADroppedHeader() async throws {
        let result = try await CurlImportTesting.importing("curl -H 'Accept:' https://a.example")

        #expect(result.ignored == ["-H Accept:"])
        #expect(result.request.headers.isEmpty)
    }

    @Test("The summary reads \"Ignored:\" and the list")
    func summarises() async throws {
        let result = try await CurlImportTesting.importing("curl -s --data @a.json -o out https://a.example")

        #expect(result.ignoredSummary == "Ignored: -s, --data @a.json and -o")
    }

    @Test("Nothing ignored means no summary")
    func noSummary() async throws {
        #expect(try await CurlImportTesting.importing("curl https://a.example").ignoredSummary == nil)
    }

    @Test("The imported summary names the request")
    func importedSummary() async throws {
        let result = try await CurlImportTesting.importing("curl https://a.example/users")

        #expect(result.importedSummary == "Imported \u{201C}GET /users\u{201D}.")
    }

}
