//  CodeRequest+URLSession.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore

nonisolated extension CodeRequest {

    var urlSession: String {
        let setup = ["var request = URLRequest(url: URL(string: \(address.swiftLiteral))!)"]
            + methodLines
            + headers.map(\.urlSessionLine)
            + basicLines
            + bodyLines
        let send = [
            "let (data, response) = try await URLSession.shared.data(for: request)",
            "print(response)",
            "print(String(decoding: data, as: UTF8.self))"
        ]
        let comments = notes.map { "// \($0)" }
        return (comments + ["import Foundation", ""] + setup + [""] + send).joined(separator: "\n")
    }

    private var methodLines: [String] {
        method == .get ? [] : ["request.httpMethod = \(method.rawValue.swiftLiteral)"]
    }

    /// Worked out when the code runs, so the password can be filled in.
    private var basicLines: [String] {
        guard let basicCredentials else {
            return []
        }
        return [
            "let credentials = Data(\(basicCredentials.swiftLiteral).utf8).base64EncodedString()",
            #"request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")"#
        ]
    }

    private var bodyLines: [String] {
        switch body {
        case .none: []
        case .text(let text): ["request.httpBody = Data(\(text.swiftLiteral).utf8)"]
        case .file(let path): ["request.httpBody = try Data(contentsOf: URL(filePath: \(path.swiftLiteral)))"]
        case .form(let parts): formLines(parts)
        }
    }

    private func formLines(_ parts: [CodeFormPart]) -> [String] {
        let declaresItsBoundary = !headers.contains(where: \.isContentType)
        let boundaryHeader = #"request.setValue("multipart/form-data; boundary=\(boundary)", "#
            + #"forHTTPHeaderField: "Content-Type")"#

        return ["let boundary = UUID().uuidString", "var body = Data()"]
            + parts.flatMap(\.urlSessionLines)
            + [#"body.append(Data("--\(boundary)--\r\n".utf8))"#]
            + (declaresItsBoundary ? [boundaryHeader] : [])
            + ["request.httpBody = body"]
    }

}

private nonisolated extension CodeHeader {

    var urlSessionLine: String {
        "request.addValue(\(value.swiftLiteral), forHTTPHeaderField: \(name.swiftLiteral))"
    }

}

private nonisolated extension CodeFormPart {

    var urlSessionLines: [String] {
        switch content {
        case .text(let text):
            return [#"body.append(Data("--\(boundary)\r\n\#(head())\r\n\r\n\#(text.swiftEscaped)\r\n".utf8))"#]
        case .file(let path):
            let filename = path.split(separator: "/").last.map(String.init) ?? path
            return [
                #"body.append(Data("--\(boundary)\r\n\#(head(filename: filename))\r\n\r\n".utf8))"#,
                "try body.append(Data(contentsOf: URL(filePath: \(path.swiftLiteral))))",
                #"body.append(Data("\r\n".utf8))"#
            ]
        }
    }

    private func head(filename: String? = nil) -> String {
        let filenameParameter = filename.map { #"; filename="\#($0.multipartNameEscaped)""# } ?? ""
        let disposition = #"Content-Disposition: form-data; name="\#(name.multipartNameEscaped)""# + filenameParameter
        let lines = [disposition] + (contentType.map { ["Content-Type: \($0)"] } ?? [])
        return lines.map(\.swiftEscaped).joined(separator: #"\r\n"#)
    }

}
