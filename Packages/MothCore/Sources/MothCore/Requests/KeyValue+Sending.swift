//  KeyValue+Sending.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated extension KeyValue {

    var isSent: Bool {
        isEnabled && !key.isEmpty
    }

    var percentEncodedPair: String {
        "\(key.percentEncoded)=\(value.percentEncoded)"
    }

    var displayEncodedPair: String {
        "\(key.urlDisplayEncoded)=\(value.urlDisplayEncoded)"
    }

}

nonisolated extension [KeyValue] {

    func row(filling pathVariable: String) -> KeyValue? {
        first { $0.isSent && $0.key == pathVariable && !$0.value.isEmpty }
    }

}
