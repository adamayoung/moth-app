//  CurlImportMappingTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct CurlImportMappingTests {

    private static let formType = "application/x-www-form-urlencoded"

    @Test(
        "The method is what curl would send",
        arguments: [
            ("curl https://a.example", "GET"),
            ("curl -d a=1 https://a.example", "POST"),
            ("curl --data-raw a=1 https://a.example", "POST"),
            ("curl -F a=1 https://a.example", "POST"),
            ("curl -G -d a=1 https://a.example", "GET"),
            ("curl --get -d a=1 https://a.example", "GET"),
            ("curl -X PUT -d a=1 https://a.example", "PUT"),
            ("curl -X DELETE -G -d a=1 https://a.example", "DELETE")
        ]
    )
    func method(text: String, method: String) async throws {
        #expect(try await CurlImportTesting.request(text).method.rawValue == method)
    }

    @Test("A URL's query moves to rows, decoded, because a template and rows would both be sent")
    func queryMovesToRows() async throws {
        let request = try await CurlImportTesting.request("curl 'https://a.example/users?limit=10&q=a%20b+c'")

        #expect(request.urlTemplate == "https://a.example/users")
        #expect(request.queryParameters.pairs == [Pair("limit", "10"), Pair("q", "a b c")])
    }

    @Test("A variable and a fragment survive in the template")
    func keepsVariablesAndFragments() async throws {
        let request = try await CurlImportTesting.request("curl '{{host}}/users?a={{b}}#top'")

        #expect(request.urlTemplate == "{{host}}/users#top")
        #expect(request.queryParameters.pairs == [Pair("a", "{{b}}")])
    }

    @Test("A URL with no query stays as written")
    func keepsAPlainURL() async throws {
        let request = try await CurlImportTesting.request("curl example.com/users")

        #expect(request.urlTemplate == "example.com/users")
        #expect(request.queryParameters.isEmpty)
    }

    @Test("-G moves the data to the query, after the URL's own rows, and leaves no body")
    func getMovesDataToQuery() async throws {
        let request = try await CurlImportTesting.request(
            "curl -G -d a=1 --data-urlencode 'b=c d' 'https://a.example/x?z=1'"
        )

        #expect(request.urlTemplate == "https://a.example/x")
        #expect(request.queryParameters.pairs == [Pair("z", "1"), Pair("a", "1"), Pair("b", "c d")])
        #expect(request.body == .none)
    }

    @Test("Headers keep their order and everything after the first colon")
    func headers() async throws {
        let request = try await CurlImportTesting.request(
            "curl -H 'Accept: a/b' --header 'X-Time:12:30' -H 'X-Empty;' https://a.example"
        )

        #expect(request.headers.pairs == [
            Pair("Accept", "a/b"), Pair("X-Time", "12:30"), Pair("X-Empty", "")
        ])
    }

    @Test(
        "-A, -e and -b become headers",
        arguments: [
            ("curl -A agent https://a.example", Pair("User-Agent", "agent")),
            ("curl --user-agent agent https://a.example", Pair("User-Agent", "agent")),
            ("curl -e https://b.example https://a.example", Pair("Referer", "https://b.example")),
            ("curl --referer https://b.example https://a.example", Pair("Referer", "https://b.example")),
            ("curl -b a=1 https://a.example", Pair("Cookie", "a=1")),
            ("curl --cookie 'a=1; b=2' https://a.example", Pair("Cookie", "a=1; b=2"))
        ]
    )
    func headerFlags(text: String, header: Pair) async throws {
        #expect(try await CurlImportTesting.request(text).headers.pairs == [header])
    }

    @Test("A header wins over the flag, as curl's own header gives way to a custom one")
    func explicitHeaderWins() async throws {
        let request = try await CurlImportTesting.request(
            "curl -A flag -H 'user-agent: header' -e flag -H 'REFERER: header' -b a=1 -H 'Cookie: b=2' https://a.example"
        )

        #expect(request.headers.pairs == [
            Pair("user-agent", "header"), Pair("REFERER", "header"), Pair("Cookie", "b=2")
        ])
    }

    @Test("The last -A wins, and each -b keeps a row, because the builder joins Cookie rows")
    func repeatedHeaderFlags() async throws {
        let request = try await CurlImportTesting.request("curl -A a -A b -b a=1 -b b=2 https://a.example")

        #expect(request.headers.pairs == [Pair("User-Agent", "b"), Pair("Cookie", "a=1"), Pair("Cookie", "b=2")])
    }

    @Test("A body takes the Content-Type header's type, whatever its case")
    func rawBodyTakesTheHeader() async throws {
        let request = try await CurlImportTesting.request(
            #"curl -H 'content-type: application/json' -d '{"a":1}' https://a.example"#
        )

        #expect(request.body == .raw(content: #"{"a":1}"#, contentType: "application/json"))
        #expect(request.headers.pairs == [Pair("content-type", "application/json")])
    }

    @Test("A body that isn't pairs takes the form type curl would send, and stays raw")
    func rawBodyWithoutAHeader() async throws {
        let request = try await CurlImportTesting.request(#"curl -d '{"a=b":1}' https://a.example"#)

        #expect(request.body == .raw(content: #"{"a=b":1}"#, contentType: Self.formType))
    }

    @Test("Form pairs become rows, joined across flags and decoded, because the builder encodes them")
    func formPairsBecomeRows() async throws {
        let request = try await CurlImportTesting.request(
            "curl -d a=1 --data 'b=c%20d+e' --data-ascii f=g --data-binary h=i --data-raw j=k https://a.example"
        )

        #expect(rows(of: request.body) == [
            Pair("a", "1"), Pair("b", "c d e"), Pair("f", "g"), Pair("h", "i"), Pair("j", "k")
        ])
    }

    @Test("A # in a form value is text, not a fragment")
    func formValueKeepsAHash() async throws {
        let request = try await CurlImportTesting.request("curl -d 'a=b#c' https://a.example")

        #expect(rows(of: request.body) == [Pair("a", "b#c")])
    }

    @Test("An explicit form type still makes rows, and a charset doesn't stop it")
    func explicitFormTypeMakesRows() async throws {
        let request = try await CurlImportTesting.request(
            "curl -H 'Content-Type: application/x-www-form-urlencoded; charset=utf-8' -d a=1 https://a.example"
        )

        #expect(rows(of: request.body) == [Pair("a", "1")])
    }

    @Test("Pairs under another type stay raw")
    func otherTypeStaysRaw() async throws {
        let request = try await CurlImportTesting.request(
            "curl -H 'Content-Type: text/plain' -d a=1 https://a.example"
        )

        #expect(request.body == .raw(content: "a=1", contentType: "text/plain"))
    }

    @Test("--data-raw takes an @ literally")
    func dataRawKeepsAnAt() async throws {
        let result = try await CurlImportTesting.importing("curl --data-raw @handle https://a.example")

        #expect(result.request.body == .raw(content: "@handle", contentType: Self.formType))
        #expect(result.ignored.isEmpty)
    }

    @Test(
        "--data-urlencode takes each of curl's forms",
        arguments: [
            ("name=a b", [Pair("name", "a b")]),
            ("name=+1&2", [Pair("name", "+1&2")]),
            ("name=a@b.example", [Pair("name", "a@b.example")])
        ]
    )
    func dataURLEncodePairs(value: String, expected: [Pair]) async throws {
        let request = try await CurlImportTesting.request("curl --data-urlencode '\(value)' https://a.example")

        #expect(rows(of: request.body) == expected)
    }

    @Test("--data-urlencode with no name sends the content encoded", arguments: ["a b", "=a b"])
    func dataURLEncodeContent(value: String) async throws {
        let request = try await CurlImportTesting.request("curl --data-urlencode '\(value)' https://a.example")

        #expect(request.body == .raw(content: "a%20b", contentType: Self.formType))
    }

    @Test("An empty -d is a POST with no body")
    func emptyData() async throws {
        let request = try await CurlImportTesting.request("curl -d '' https://a.example")

        #expect(request.method == .post)
        #expect(request.body == .none)
    }

    @Test("-F makes form rows: text, a file by path, and a stated type")
    func form() async throws {
        let request = try await CurlImportTesting.request(#"""
        curl -F a=b --form 'c=@/tmp/d.png;type=image/png' -F 'e="f;g";type=text/plain' \
          -F 'h=@"i j.txt"' a.example
        """#)

        guard case .formData(let fields) = request.body else {
            Issue.record("Expected form-data")
            return
        }
        #expect(fields.map(\.key) == ["a", "c", "e", "h"])
        #expect(fields.map(\.value) == [
            .text("b"), .file(paths: ["/tmp/d.png"]), .text("f;g"), .file(paths: ["i j.txt"])
        ])
        #expect(fields.map(\.contentType) == [nil, "image/png", "text/plain", nil])
    }

    @Test(
        "Redirects follow only with -L, as in curl",
        arguments: [
            ("curl https://a.example", false),
            ("curl -L https://a.example", true),
            ("curl --location https://a.example", true)
        ]
    )
    func redirects(text: String, follows: Bool) async throws {
        #expect(try await CurlImportTesting.request(text).settings.followsRedirects == follows)
    }

    @Test(
        "TLS goes unverified only with -k",
        arguments: [
            ("curl https://a.example", true),
            ("curl -k https://a.example", false),
            ("curl --insecure https://a.example", false)
        ]
    )
    func tls(text: String, verifies: Bool) async throws {
        #expect(try await CurlImportTesting.request(text).settings.verifiesTLS == verifies)
    }

    @Test("--compressed is accepted and ignored, without being listed")
    func compressed() async throws {
        let result = try await CurlImportTesting.importing("curl --compressed https://a.example")

        #expect(result.ignored.isEmpty)
        #expect(result.request.headers.isEmpty)
    }

    @Test(
        "The name is the method and the URL's path",
        arguments: [
            ("curl https://a.example/users", "GET /users"),
            ("curl -X DELETE https://a.example/users/1", "DELETE /users/1"),
            ("curl -d a=1 https://a.example/v1/customers", "POST /v1/customers"),
            ("curl 'https://a.example/users?limit=10#top'", "GET /users"),
            ("curl https://a.example", "GET /"),
            ("curl https://a.example:8080/x", "GET /x"),
            ("curl example.com/users", "GET /users"),
            ("curl localhost:8080/users", "GET /users"),
            ("curl '{{host}}/users'", "GET /users"),
            ("curl https://user:pass@a.example/users", "GET /users")
        ]
    )
    func name(text: String, name: String) async throws {
        #expect(try await CurlImportTesting.request(text).name == name)
    }

    @Test("The shape a browser's Copy as cURL writes: ANSI-C quoting, -b and --data-raw, with nothing listed")
    func browserCopyAsCurl() async throws {
        let result = try await CurlImportTesting.importing(#"""
        curl 'https://a.example/api/items?page=2' \
          -H 'accept: */*' \
          -H 'content-type: application/json' \
          -b 'session=abc; theme=dark' \
          -H 'priority: u=1, i' \
          -H 'user-agent: Mozilla/5.0' \
          --data-raw $'{"name":"it\'s","note":"a\\nb!"}'
        """#)
        let request = result.request

        #expect(result.ignored.isEmpty)
        #expect(request.name == "POST /api/items")
        #expect(request.queryParameters.pairs == [Pair("page", "2")])
        #expect(request.headers.pairs == [
            Pair("accept", "*/*"),
            Pair("content-type", "application/json"),
            Pair("priority", "u=1, i"),
            Pair("user-agent", "Mozilla/5.0"),
            Pair("Cookie", "session=abc; theme=dark")
        ])
        #expect(request.body == .raw(
            content: #"{"name":"it's","note":"a\nb!"}"#,
            contentType: "application/json"
        ))
    }

    private func rows(of body: RequestBody) -> [Pair] {
        guard case .urlEncoded(let rows) = body else {
            return []
        }
        return rows.pairs
    }

}
