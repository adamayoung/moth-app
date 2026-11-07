//  CurlCommand.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

/// What a command asks for, in curl's terms. Reads no file and runs nothing: what would need either is listed.
nonisolated struct CurlCommand {

    private static let otherAuthSchemes: Set = [
        "--anyauth", "--aws-sigv4", "--digest", "--expand-aws-sigv4", "--negotiate", "--ntlm", "--ntlm-wb",
        "--oauth2-bearer"
    ]

    private(set) var method: String?
    private(set) var urls: [String] = []
    private(set) var headers: [KeyValue] = []
    private(set) var cookies: [String] = []
    private(set) var userAgent: String?
    private(set) var referer: String?
    private(set) var user: String?
    private(set) var hasData = false
    private(set) var dataParts: [String] = []
    private(set) var hasForm = false
    private(set) var formFields: [FormDataField] = []
    private(set) var movesDataToQuery = false
    private(set) var followsRedirects = false
    private(set) var verifiesTLS = true
    private(set) var ignored: [String] = []

    private var words: ArraySlice<String>
    private var userFlag: String?

    init(_ text: String) throws {
        guard let shell = try? ShellWords(text) else {
            throw CurlImportError.notACurlCommand
        }
        let command = shell.words.drop { $0 == "$" || $0 == "%" }
        guard let program = command.first, program == "curl" || program.hasSuffix("/curl") else {
            throw CurlImportError.notACurlCommand
        }

        self.words = command.dropFirst()
        while let word = words.popFirst() {
            try read(word)
        }
        (urls.dropFirst() + shell.redirections).forEach { ignore($0) }
        if usesAnotherAuthScheme, let userFlag {
            self.user = nil
            ignore(userFlag)
        }
        if let rest = shell.rest {
            ignore(rest)
        }

        // curl itself refuses -F beside -d.
        guard !urls.isEmpty, !(hasForm && hasData) else {
            throw CurlImportError.notACurlCommand
        }
    }

    /// Moth would send these credentials as Basic, which gives away what the named scheme keeps off the wire.
    var usesAnotherAuthScheme: Bool {
        !Self.otherAuthSchemes.isDisjoint(with: ignored)
    }

    private mutating func read(_ word: String) throws {
        if word.hasPrefix("--"), word.count > 2 {
            try readLong(word)
        } else if word.hasPrefix("-"), word.count > 1 {
            try readShort(word)
        } else if !word.isEmpty {
            urls.append(word)
        }
    }

    private mutating func readLong(_ word: String) throws {
        let name = String(word.dropFirst(2))
        if let option = CurlOption(long: name) {
            try apply(option, value: option.takesValue ? nextValue() : "", flag: word)
        } else {
            ignore(word)
            if IgnoredCurlOptions.takesValue(long: name) {
                _ = try nextValue()
            }
        }
    }

    private mutating func readShort(_ word: String) throws {
        var letters = word.dropFirst()
        while let letter = letters.popFirst() {
            let flag = "-\(letter)"
            if let option = CurlOption(short: letter) {
                if option.takesValue {
                    try apply(option, value: letters.isEmpty ? nextValue() : String(letters), flag: flag)
                    return
                }
                try apply(option, value: "", flag: flag)
            } else {
                ignore(flag)
                if IgnoredCurlOptions.takesValue(short: letter) {
                    if letters.isEmpty {
                        _ = try nextValue()
                    }
                    return
                }
            }
        }
    }

    private mutating func nextValue() throws -> String {
        guard let value = words.popFirst() else {
            throw CurlImportError.notACurlCommand
        }
        return value
    }

    private mutating func apply(_ option: CurlOption, value: String, flag: String) throws {
        switch option {
        case .request: method = value.uppercased()
        case .header: addHeader(value, flag: flag)
        case .data: addData(value, flag: flag)
        case .dataRaw: addRawData(value)
        case .dataURLEncode: addURLEncodedData(value, flag: flag)
        case .form: addFormField(value, flag: flag)
        case .get: movesDataToQuery = true
        case .userAgent: userAgent = value
        case .referer: referer = value
        case .cookie: addCookie(value, flag: flag)
        case .url: urls.append(value)
        case .user:
            user = value
            userFlag = flag
        case .location: followsRedirects = true
        case .insecure: verifiesTLS = false
        case .compressed: break
        }
    }

    private mutating func addHeader(_ text: String, flag: String) {
        if let separator = text.firstIndex(of: ":"), !text.hasPrefix("@") {
            let value = text[text.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else {
                return ignore("\(flag) \(text)")
            }
            headers.append(KeyValue(key: String(text[..<separator]), value: value))
        } else if text.hasSuffix(";"), !text.hasPrefix("@") {
            headers.append(KeyValue(key: String(text.dropLast()), value: ""))
        } else {
            ignore("\(flag) \(text)")
        }
    }

    private mutating func addCookie(_ text: String, flag: String) {
        if text.contains("=") {
            cookies.append(text)
        } else {
            ignore("\(flag) \(text)")
        }
    }

    private mutating func addData(_ text: String, flag: String) {
        hasData = true
        if text.hasPrefix("@") {
            ignore("\(flag) \(text)")
        } else {
            dataParts.append(text)
        }
    }

    private mutating func addRawData(_ text: String) {
        hasData = true
        dataParts.append(text)
    }

    /// curl's forms are `content`, `=content`, `name=content`, `@file` and `name@file`.
    private mutating func addURLEncodedData(_ text: String, flag: String) {
        hasData = true
        guard let separator = text.firstIndex(of: "=") ?? text.firstIndex(of: "@") else {
            dataParts.append(text.percentEncoded)
            return
        }
        guard text[separator] == "=" else {
            return ignore("\(flag) \(text)")
        }

        let name = text[..<separator]
        let content = String(text[text.index(after: separator)...]).percentEncoded
        dataParts.append(name.isEmpty ? content : "\(name)=\(content)")
    }

    private mutating func addFormField(_ text: String, flag: String) {
        hasForm = true
        if let field = FormDataField(curlArgument: text) {
            formFields.append(field)
        } else {
            ignore("\(flag) \(text)")
        }
    }

    private mutating func ignore(_ item: String) {
        if !ignored.contains(item) {
            ignored.append(item)
        }
    }

}

private nonisolated extension FormDataField {

    /// Nil for `name=<file`, which takes its text from a file, and for text with no name.
    init?(curlArgument text: String) {
        guard let separator = text.firstIndex(of: "="), separator != text.startIndex else {
            return nil
        }
        var argument = text[text.index(after: separator)...]
        guard !argument.hasPrefix("<") else {
            return nil
        }
        let isFile = argument.hasPrefix("@")
        if isFile {
            argument = argument.dropFirst()
        }

        let (content, attributes) = Self.split(argument)
        self.init(
            key: String(text[..<separator]),
            value: isFile ? .file(paths: [content]) : .text(content),
            contentType: Self.contentType(in: attributes)
        )
    }

    /// A type's own parameters run on after it, up to curl's next attribute.
    private static func contentType(in attributes: Substring) -> String? {
        let parts = attributes.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let start = parts.firstIndex(where: { $0.hasPrefix("type=") }) else {
            return nil
        }
        let parameters = parts[(start + 1)...].prefix { part in
            !["filename=", "headers=", "encoder="].contains { part.hasPrefix($0) }
        }
        return ([String(parts[start].dropFirst(5))] + parameters).joined(separator: ";")
    }

    /// A value in double quotes can hold a `;`, and a backslash there escapes only a backslash or a quote.
    private static func split(_ argument: Substring) -> (content: String, attributes: Substring) {
        guard argument.hasPrefix("\"") else {
            let end = argument.firstIndex(of: ";") ?? argument.endIndex
            return (String(argument[..<end]), argument[end...])
        }

        var content = ""
        var rest = argument.dropFirst()
        while let character = rest.popFirst(), character != "\"" {
            if character == "\\", rest.first == "\\" || rest.first == "\"" {
                content.append(rest.removeFirst())
            } else {
                content.append(character)
            }
        }
        return (content, rest)
    }

}
