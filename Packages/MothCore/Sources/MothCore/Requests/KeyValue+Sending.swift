//  KeyValue+Sending.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated extension KeyValue {

    public var isSent: Bool {
        isEnabled && !key.isEmpty
    }

    var percentEncodedPair: String {
        "\(key.percentEncoded)=\(value.percentEncoded)"
    }

}
