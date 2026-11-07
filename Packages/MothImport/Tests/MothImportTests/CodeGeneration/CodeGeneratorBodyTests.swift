//  CodeGeneratorBodyTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct CodeGeneratorBodyTests {

    private func code(
        _ body: RequestBody,
        method: HTTPMethod = .post,
        headers: [KeyValue] = []
    ) async throws -> GeneratedCode {
        try await CodeGenerator().code(
            for: Request(
                name: "Users",
                method: method,
                urlTemplate: "https://example.com",
                headers: headers,
                body: body
            ),
            scopes: VariableScopes()
        )
    }

    @Test("A raw body carries its content type")
    func raw() async throws {
        let code = try await code(.raw(content: #"{"name":"Ada"}"#, contentType: "application/json"))

        #expect(code.curl == """
        curl --url 'https://example.com' \\
          --request 'POST' \\
          --header 'Content-Type: application/json' \\
          --data-raw '{"name":"Ada"}'
        """)
        #expect(code.swift.contains(#"request.addValue("application/json", forHTTPHeaderField: "Content-Type")"#))
        #expect(code.swift.contains(#"request.httpBody = Data("{\"name\":\"Ada\"}".utf8)"#))
    }

    @Test("A raw body with no content type adds no header")
    func rawWithoutContentType() async throws {
        let code = try await code(.raw(content: "text", contentType: ""))

        #expect(code.curl.contains("--data-raw 'text'"))
        #expect(!code.curl.contains("Content-Type"))
        #expect(!code.swift.contains("Content-Type"))
    }

    @Test("A manual Content-Type replaces the body's, as it does on Send")
    func manualContentType() async throws {
        let code = try await code(
            .raw(content: "text", contentType: "text/plain"),
            headers: [KeyValue(key: "content-type", value: "text/csv")]
        )

        #expect(code.curl.contains("--header 'content-type: text/csv'"))
        #expect(!code.curl.contains("text/plain"))
    }

    @Test("A urlencoded body sends its enabled rows, encoded, with variables left readable")
    func urlEncoded() async throws {
        let code = try await code(.urlEncoded([
            KeyValue(key: "first name", value: "Ada & Co"),
            KeyValue(key: "token", value: "{{token}}"),
            KeyValue(key: "draft", value: "1", isEnabled: false)
        ]))

        #expect(code.curl.contains("--header 'Content-Type: application/x-www-form-urlencoded'"))
        #expect(code.curl.contains("--data-raw 'first%20name=Ada%20%26%20Co&token={{token}}'"))
        #expect(code.swift.contains(#"Data("first%20name=Ada%20%26%20Co&token={{token}}".utf8)"#))
    }

    @Test("A urlencoded body with no rows sends nothing")
    func emptyURLEncoded() async throws {
        let code = try await code(.urlEncoded([]))

        #expect(!code.curl.contains("--data"))
        #expect(!code.curl.contains("Content-Type"))
    }

    @Test("A form-data body sends text literally and files by reference, and leaves out disabled rows")
    func formDataInCURL() async throws {
        let code = try await code(.formData([
            FormDataField(key: "name", value: .text("@Ada")),
            FormDataField(key: "note", value: .text(#"say "hi""#), contentType: "text/plain"),
            FormDataField(key: "photo", value: .file(paths: ["/tmp/a.png", "/tmp/b.png"]), contentType: "image/png"),
            FormDataField(key: "draft", value: .text("1"), isEnabled: false)
        ]))

        #expect(code.curl == #"""
        curl --url 'https://example.com' \
          --request 'POST' \
          --form-string 'name=@Ada' \
          --form 'note="say \"hi\"";type=text/plain' \
          --form 'photo=@"/tmp/a.png";type=image/png' \
          --form 'photo=@"/tmp/b.png";type=image/png'
        """#)
    }

    @Test("Form-data in Swift builds a multipart body around one boundary")
    func formDataInSwift() async throws {
        let code = try await code(.formData([
            FormDataField(key: "name", value: .text("Ada")),
            FormDataField(key: "photo", value: .file(paths: ["/tmp/a.png"]), contentType: "image/png")
        ]))

        #expect(code.swift == #"""
        import Foundation

        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\nAda\r\n".utf8))
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"a.png\"\r\nContent-Type: image/png\r\n\r\n".utf8))
        try body.append(Data(contentsOf: URL(filePath: "/tmp/a.png")))
        body.append(Data("\r\n".utf8))
        body.append(Data("--\(boundary)--\r\n".utf8))
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        print(response)
        print(String(decoding: data, as: UTF8.self))
        """#)
    }

    @Test("A manual Content-Type on form-data stays, and takes the boundary's place")
    func formDataWithManualContentType() async throws {
        let code = try await code(
            .formData([FormDataField(key: "name", value: .text("Ada"))]),
            headers: [KeyValue(key: "Content-Type", value: "multipart/mixed")]
        )

        #expect(!code.swift.contains("multipart/form-data"))
        #expect(code.swift.contains(#"request.addValue("multipart/mixed", forHTTPHeaderField: "Content-Type")"#))
    }

    @Test("A form-data body with no rows sends nothing")
    func emptyFormData() async throws {
        let code = try await code(.formData([FormDataField(key: "draft", value: .text("1"), isEnabled: false)]))

        #expect(!code.curl.contains("--form"))
        #expect(!code.swift.contains("boundary"))
    }

    @Test("A binary body is a file reference")
    func binary() async throws {
        let code = try await code(.binary(filePath: "/tmp/health.bin"))

        #expect(code.curl.contains("--header 'Content-Type: application/octet-stream'"))
        #expect(code.curl.contains("--data-binary '@/tmp/health.bin'"))
        #expect(code.swift.contains(#"request.httpBody = try Data(contentsOf: URL(filePath: "/tmp/health.bin"))"#))
    }

    @Test("A binary body with no file gets a placeholder")
    func binaryWithoutAFile() async throws {
        let code = try await code(.binary(filePath: nil))

        #expect(code.curl.contains("--data-binary '@<file>'"))
        #expect(code.swift.contains(#"URL(filePath: "<file>")"#))
    }

    @Test("A GraphQL body is the JSON a server expects, with its variables as written")
    func graphQL() async throws {
        let code = try await code(.graphQL(query: "{ user(id: \"1\") { id } }", variables: #"{"a":1}"#))

        #expect(code.curl.contains("--header 'Content-Type: application/json'"))
        #expect(code.curl.contains(#"--data-raw '{"query":"{ user(id: \"1\") { id } }","variables":{"a":1}}'"#))
        #expect(code.swift
            .contains(#"Data("{\"query\":\"{ user(id: \\\"1\\\") { id } }\",\"variables\":{\"a\":1}}".utf8)"#))
    }

    @Test("A GraphQL body with no variables leaves the key out")
    func graphQLWithoutVariables() async throws {
        let code = try await code(.graphQL(query: "{ id }", variables: "  "))

        #expect(code.curl.contains(#"--data-raw '{"query":"{ id }"}'"#))
    }

    @Test(
        "A method that sends no body leaves it out and says so, as Send does",
        arguments: [HTTPMethod.get, .head]
    )
    func bodyOnAMethodWithoutOne(method: HTTPMethod) async throws {
        let code = try await code(.raw(content: "text", contentType: "text/plain"), method: method)

        let comment = "The body is left out, because \(method.rawValue) doesn\u{2019}t send one."
        #expect(code.curl.hasPrefix("# \(comment)\ncurl"))
        #expect(code.swift.hasPrefix("// \(comment)\nimport Foundation"))
        #expect(!code.curl.contains("text/plain"))
        #expect(!code.swift.contains("httpBody"))
    }

    @Test("An empty body on such a method needs no comment")
    func emptyBodyOnAMethodWithoutOne() async throws {
        let code = try await code(.formData([]), method: .get)

        #expect(code.curl == "curl --url 'https://example.com'")
    }

}
