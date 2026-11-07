//  ShellWordsTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

@testable import MothImport
import Testing

struct ShellWordsTests {

    @Test("Words split on spaces and tabs")
    func splitsOnBlanks() throws {
        let shell = try ShellWords("curl  -s\thttps://example.com")

        #expect(shell.words == ["curl", "-s", "https://example.com"])
        #expect(shell.rest == nil)
    }

    @Test(
        "A line continuation joins lines, as a shell reads it",
        arguments: [
            ("curl \\\n  -s \\\n  a", ["curl", "-s", "a"]),
            ("curl \\\r\n  -s", ["curl", "-s"]),
            ("cu\\\nrl", ["curl"]),
            (#""a\"# + "\n" + #"b""#, ["ab"]),
            ("'a\\\nb'", ["a\\\nb"])
        ]
    )
    func joinsContinuations(text: String, expected: [String]) throws {
        #expect(try ShellWords(text).words == expected)
    }

    @Test(
        "Quoting reads as a shell reads it",
        arguments: [
            (#"'a b'"#, ["a b"]),
            (#""a b""#, ["a b"]),
            (#"'it'\''s'"#, ["it's"]),
            (#"a'b c'd"#, ["ab cd"]),
            (#"a"b c"d"#, ["ab cd"]),
            (#"''"#, [""]),
            (#""""#, [""]),
            (#"a\ b"#, ["a b"]),
            (#"\'"#, ["'"]),
            (#"'\n'"#, [#"\n"#]),
            (#""\n""#, [#"\n"#]),
            (#""\"\$\`\\""#, [#""$`\"#]),
            (#"'$HOME'"#, ["$HOME"]),
            (#""$HOME""#, ["$HOME"]),
            (#"$HOME"#, ["$HOME"]),
            ("'a\nb'", ["a\nb"]),
            ("\"a\nb\"", ["a\nb"])
        ]
    )
    func readsQuotes(text: String, expected: [String]) throws {
        #expect(try ShellWords(text).words == expected)
    }

    @Test(
        "ANSI-C quoting, as a browser's Copy as cURL writes it",
        arguments: [
            (#"$'a\nb'"#, "a\nb"),
            (#"$'it\'s'"#, "it's"),
            (#"$'a\\b'"#, #"a\b"#),
            (#"$'\r\t'"#, "\r\t"),
            (#"$'!'"#, "!"),
            (#"$'\041'"#, "!"),
            (#"$'\x21'"#, "!"),
            (#"$'\U0001F600'"#, "😀"),
            (#"$'😀'"#, "😀"),
            (#"$'\q'"#, #"\q"#)
        ]
    )
    func readsANSIQuoting(text: String, expected: String) throws {
        #expect(try ShellWords(text).words == [expected])
    }

    @Test("A lone dollar stays literal, because only a dollar before a quote opens ANSI-C quoting")
    func keepsALoneDollar() throws {
        #expect(try ShellWords("a$ b").words == ["a$", "b"])
    }

    @Test("A quote left open is not a command", arguments: ["curl 'a", #"curl "a"#, "curl $'a"])
    func refusesAnUnclosedQuote(text: String) {
        #expect(throws: ShellWordsError.unclosedQuote) {
            try ShellWords(text)
        }
    }

    @Test("A trailing backslash stays literal, as it does with nothing to escape")
    func keepsATrailingBackslash() throws {
        #expect(try ShellWords(#"a\"#).words == [#"a\"#])
    }

    @Test("Comments and blank lines before the command are skipped")
    func skipsLeadingComments() throws {
        let shell = try ShellWords("#!/bin/sh\n\n# a comment\ncurl a")

        #expect(shell.words == ["curl", "a"])
        #expect(shell.rest == nil)
    }

    @Test("A comment after the command is skipped, and a # inside a word is not a comment")
    func skipsTrailingComments() throws {
        let shell = try ShellWords("curl a#b # c")

        #expect(shell.words == ["curl", "a#b"])
        #expect(shell.rest == nil)
    }

    @Test(
        "The command ends where a shell ends it, and what follows is kept",
        arguments: [
            ("curl a | jq .", ["curl", "a"], "| jq ."),
            ("curl a|jq", ["curl", "a"], "|jq"),
            ("curl a; echo b", ["curl", "a"], "; echo b"),
            ("curl a && echo b", ["curl", "a"], "&& echo b"),
            ("curl a > out.json", ["curl", "a"], "> out.json"),
            ("curl a?b=1&c=2", ["curl", "a?b=1"], "&c=2"),
            ("curl a\ncurl b\n", ["curl", "a"], "curl b")
        ]
    )
    func stopsAtOperators(text: String, words: [String], rest: String) throws {
        let shell = try ShellWords(text)

        #expect(shell.words == words)
        #expect(shell.rest == rest)
    }

    @Test("An operator in quotes is text", arguments: ["'a|b'", #""a;b""#, #"a\&b"#])
    func keepsQuotedOperators(text: String) throws {
        let shell = try ShellWords(text)

        #expect(shell.words.count == 1)
        #expect(shell.rest == nil)
    }

    @Test("A trailing newline ends the command with nothing after it")
    func ignoresATrailingNewline() throws {
        let shell = try ShellWords("curl a\n")

        #expect(shell.words == ["curl", "a"])
        #expect(shell.rest == nil)
    }

}
