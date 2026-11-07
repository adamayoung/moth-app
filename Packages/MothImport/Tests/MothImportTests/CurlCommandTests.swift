//  CurlCommandTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct CurlCommandTests {

    @Test(
        "Text that isn't a cURL command is refused",
        arguments: [
            "",
            "hello world",
            "wget https://example.com",
            "curlish https://example.com",
            "curl",
            "curl -s",
            "curl -X",
            "curl https://example.com -H",
            "curl 'https://example.com",
            "curl -F a=b -d c=d https://example.com"
        ]
    )
    func refuses(text: String) async {
        await #expect(throws: CurlImportError.notACurlCommand) {
            try await CurlImportTesting.importing(text)
        }
    }

    @Test(
        "-X sets the method, attached or not, and the last one wins",
        arguments: [
            ("curl -X PUT a.example", "PUT"),
            ("curl -XPUT a.example", "PUT"),
            ("curl --request PUT a.example", "PUT"),
            ("curl -X POST -X DELETE a.example", "DELETE"),
            ("curl -X put a.example", "PUT")
        ]
    )
    func readsTheMethod(text: String, method: String) async throws {
        #expect(try await CurlImportTesting.request(text).method.rawValue == method)
    }

    @Test(
        "The URL comes from a bare word or --url, wherever it sits",
        arguments: [
            "curl https://a.example/x",
            "curl --url https://a.example/x",
            "curl -s https://a.example/x -v",
            "curl -H 'a: b' https://a.example/x"
        ]
    )
    func readsTheURL(text: String) async throws {
        #expect(try await CurlImportTesting.request(text).urlTemplate == "https://a.example/x")
    }

    @Test("Short flags can share a dash, and the last can take the next word")
    func readsClusters() async throws {
        let result = try await CurlImportTesting.importing("curl -sSLu user:pass https://a.example")

        #expect(result.request.settings.followsRedirects)
        #expect(result.ignored == ["-s", "-S"])
        guard case .basic(let auth) = result.request.auth else {
            Issue.record("Expected Basic Auth")
            return
        }
        #expect(auth.username == "user")
    }

    @Test("A short flag takes the rest of its word as its value")
    func readsAttachedValues() async throws {
        let request = try await CurlImportTesting.request(#"curl -H'a: b' -d'{}' -A'agent' https://a.example"#)

        #expect(request.headers.pairs == [Pair("a", "b"), Pair("User-Agent", "agent")])
        #expect(request.body == .raw(content: "{}", contentType: "application/x-www-form-urlencoded"))
    }

    @Test(
        "An ignored flag's value is not taken for the URL",
        arguments: [
            ("curl -o out.json https://a.example", ["-o"]),
            ("curl -oout.json https://a.example", ["-o"]),
            ("curl -so out.json https://a.example", ["-s", "-o"]),
            ("curl --max-time 30 https://a.example", ["--max-time"]),
            ("curl -m 30 https://a.example", ["-m"]),
            ("curl -x proxy.example https://a.example", ["-x"]),
            ("curl --expand-header 'a: b' https://a.example", ["--expand-header"])
        ]
    )
    func skipsIgnoredValues(text: String, ignored: [String]) async throws {
        let result = try await CurlImportTesting.importing(text)

        #expect(result.request.urlTemplate == "https://a.example")
        #expect(result.ignored == ignored)
    }

    @Test("A second URL is listed, and the first is used")
    func listsFurtherURLs() async throws {
        let result = try await CurlImportTesting.importing("curl https://a.example https://b.example")

        #expect(result.request.urlTemplate == "https://a.example")
        #expect(result.ignored == ["https://b.example"])
    }

    @Test("What follows the command is listed")
    func listsTheRest() async throws {
        #expect(try await CurlImportTesting.ignored("curl https://a.example | jq .") == ["| jq ."])
    }

}
