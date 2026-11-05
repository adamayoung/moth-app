//  KeyedDecodingContainer+List.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

extension KeyedDecodingContainer {

    func decodeList<Element: Decodable>(forKey key: Key) throws -> [Element] {
        try decodeIfPresent([Element].self, forKey: key) ?? []
    }

    func decodeStringOrList(forKey key: Key) throws -> [String] {
        if let single = try? decodeIfPresent(String.self, forKey: key) {
            return [single]
        }
        return try decodeList(forKey: key)
    }

}
