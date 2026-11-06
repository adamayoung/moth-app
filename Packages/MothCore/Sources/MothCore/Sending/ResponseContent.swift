//  ResponseContent.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CoreFoundation
import Foundation

public nonisolated enum ResponseContent: Sendable, Hashable {

    case empty
    case text(String)
    case tooLarge(raw: String)
    case binary(contentType: String?, size: Int)

    /// In bytes, as the status line counts them, so a body it calls 2 MB is the one this stops at.
    public static let formattingLimit = 2_000_000

    private static let wideEncodings: Set<String.Encoding> = [
        .utf16, .utf16BigEndian, .utf16LittleEndian, .utf32, .utf32BigEndian, .utf32LittleEndian
    ]

    public init(body: Data, contentType: String?) {
        guard !body.isEmpty else {
            self = .empty
            return
        }
        guard let text = Self.decoded(body, contentType: contentType) else {
            self = .binary(contentType: contentType, size: body.count)
            return
        }
        guard body.count <= Self.formattingLimit else {
            self = .tooLarge(raw: text)
            return
        }
        self = .text(JSONReindenter.reindented(text) ?? text)
    }

    /// Goes by the bytes rather than the content type, because servers mislabel binary as text.
    private static func decoded(_ body: Data, contentType: String?) -> String? {
        let encoding = declaredEncoding(in: contentType) ?? .utf8
        guard wideEncodings.contains(encoding) || !body.contains(0) else {
            return nil
        }
        return String(data: body, encoding: encoding)
    }

    private static func declaredEncoding(in contentType: String?) -> String.Encoding? {
        guard let name = charsetName(in: contentType) else {
            return nil
        }
        let encoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard encoding != kCFStringEncodingInvalidId else {
            return nil
        }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
    }

    private static func charsetName(in contentType: String?) -> String? {
        let parameters = contentType?.split(separator: ";").dropFirst() ?? []
        for parameter in parameters {
            let pair = parameter.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t\""))
            }
            if pair.count == 2, pair[0].caseInsensitiveCompare("charset") == .orderedSame {
                return pair[1]
            }
        }
        return nil
    }

}
