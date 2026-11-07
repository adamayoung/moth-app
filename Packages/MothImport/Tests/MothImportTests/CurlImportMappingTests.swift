//  CurlImportMappingTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct CurlImportMappingTests {

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

    @Test(
        "A query rows can't send back unchanged stays in the template, which goes out as written",
        arguments: [
            "https://a.example/svc?wsdl",
            "https://a.example/s?q=caf%E9",
            "https://a.example/s?a=1&flag",
            "https://a.example/s?=x"
        ]
    )
    func keepsAQueryRowsCantHold(url: String) async throws {
        let request = try await CurlImportTesting.request("curl '\(url)'")

        #expect(request.urlTemplate == url)
        #expect(request.queryParameters.isEmpty)
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

}
