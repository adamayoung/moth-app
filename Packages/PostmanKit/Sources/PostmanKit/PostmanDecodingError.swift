//  PostmanDecodingError.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public enum PostmanDecodingError: Error, Sendable, Equatable {

    case unsupportedSchema(found: String?)

}
