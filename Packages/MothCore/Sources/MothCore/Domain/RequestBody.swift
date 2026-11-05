//  RequestBody.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated enum RequestBody: Sendable, Hashable {

    case none
    case formData([FormDataField])
    case urlEncoded([KeyValue])
    case raw(content: String, contentType: String)
    case binary(filePath: String?)
    case graphQL(query: String, variables: String)

}
