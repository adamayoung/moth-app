//  ResponseContentTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct ResponseContentTests {

    private func content(_ text: String, contentType: String? = nil) -> ResponseContent {
        ResponseContent(body: Data(text.utf8), contentType: contentType)
    }

    @Test("JSON is indented by two spaces")
    func indentsJSON() {
        #expect(content(#"{"a":1,"b":[true,null]}"#) == .text("""
        {
          "a": 1,
          "b": [
            true,
            null
          ]
        }
        """))
    }

    @Test("JSON keeps the server's key order")
    func keepsKeyOrder() {
        #expect(content(#"{"z":1,"a":2,"m":3}"#) == .text("""
        {
          "z": 1,
          "a": 2,
          "m": 3
        }
        """))
    }

    @Test("JSON keeps a number's text exactly as sent")
    func keepsNumbers() {
        #expect(content(#"[1.10,12345678901234567890,1e3]"#) == .text("""
        [
          1.10,
          12345678901234567890,
          1e3
        ]
        """))
    }

    @Test("An empty object or array stays on one line")
    func emptyContainers() {
        #expect(content(#"{"a":{ },"b":[  ]}"#) == .text("""
        {
          "a": {},
          "b": []
        }
        """))
    }

    @Test("Structure characters and escaped quotes in a string are left alone")
    func leavesStringsAlone() {
        #expect(content(#"{"a":"{[,:\"]} "}"#) == .text("""
        {
          "a": "{[,:\\"]} "
        }
        """))
    }

    @Test("Whitespace between tokens is replaced")
    func replacesWhitespace() {
        #expect(content("{\n\t\"a\" :\r\n 1 }\n") == .text("""
        {
          "a": 1
        }
        """))
    }

    @Test("Text that isn't JSON stays as it came", arguments: ["Hello", "{\"a\":", "<html></html>", "{'a':1}"])
    func keepsOtherText(text: String) {
        #expect(content(text) == .text(text))
    }

    @Test("A body of exactly the limit is formatted")
    func formatsAtTheLimit() {
        let body = "[" + String(repeating: " ", count: ResponseContent.formattingLimit - 2) + "]"

        #expect(content(body) == .text("[]"))
    }

    @Test("A body one byte over the limit keeps its raw text")
    func stopsOverTheLimit() {
        let body = "[" + String(repeating: " ", count: ResponseContent.formattingLimit - 1) + "]"

        #expect(content(body) == .tooLarge(raw: body))
    }

    @Test("The limit is 2 MB")
    func limit() {
        #expect(ResponseContent.formattingLimit == 2_000_000)
    }

    @Test("A body with a NUL byte is binary, with its content type and size")
    func nulIsBinary() {
        let body = Data([0x50, 0x4E, 0x47, 0x00, 0x01])

        #expect(
            ResponseContent(body: body, contentType: "image/png") == .binary(contentType: "image/png", size: 5)
        )
    }

    @Test("A body that isn't valid UTF-8 is binary, even with no content type")
    func invalidUTF8IsBinary() {
        #expect(
            ResponseContent(body: Data([0xFF, 0xFE, 0x41]), contentType: nil) == .binary(contentType: nil, size: 3)
        )
    }

    @Test("A text content type doesn't make binary bytes into text")
    func mislabelledBinary() {
        let body = Data([0x41, 0x00, 0x42])

        #expect(
            ResponseContent(body: body, contentType: "text/plain") == .binary(contentType: "text/plain", size: 3)
        )
    }

    @Test("A text type with no charset falls back to Latin-1 when its bytes aren't UTF-8")
    func undeclaredLegacyText() {
        let body = Data([0x63, 0x61, 0x66, 0xE9])

        #expect(ResponseContent(body: body, contentType: "text/html") == .text("café"))
        #expect(ResponseContent(body: body, contentType: "TEXT/plain; format=flowed") == .text("café"))
    }

    @Test("A non-text type gets no Latin-1 fallback")
    func noFallbackForOtherTypes() {
        let body = Data([0x63, 0x61, 0x66, 0xE9])

        #expect(
            ResponseContent(body: body, contentType: "application/octet-stream")
                == .binary(contentType: "application/octet-stream", size: 4)
        )
    }

    @Test("A declared UTF-8 charset doesn't make binary bytes into text")
    func binaryDeclaredAsUTF8() {
        let contentType = "text/plain; charset=utf-8"

        #expect(
            ResponseContent(body: Data([0x41, 0x00]), contentType: contentType)
                == .binary(contentType: contentType, size: 2)
        )
    }

    @Test("A body that declares its charset decodes with it")
    func declaredCharset() {
        let body = Data([0x63, 0x61, 0x66, 0xE9])

        #expect(ResponseContent(body: body, contentType: "text/plain; charset=ISO-8859-1") == .text("café"))
    }

    @Test("A quoted charset is read")
    func quotedCharset() {
        let body = Data([0x63, 0x61, 0x66, 0xE9])

        #expect(ResponseContent(body: body, contentType: #"text/plain;charset="iso-8859-1""#) == .text("café"))
    }

    @Test("A declared UTF-16 body is text even though it holds NUL bytes")
    func utf16Charset() throws {
        let body = try #require("hi".data(using: .utf16LittleEndian))

        #expect(ResponseContent(body: body, contentType: "text/plain; charset=utf-16le") == .text("hi"))
    }

    @Test("An unknown charset falls back to UTF-8")
    func unknownCharset() {
        #expect(content("café", contentType: "text/plain; charset=nonsense") == .text("café"))
    }

    @Test("An empty body is empty")
    func emptyBody() {
        #expect(ResponseContent(body: Data(), contentType: "application/json") == .empty)
    }

}
