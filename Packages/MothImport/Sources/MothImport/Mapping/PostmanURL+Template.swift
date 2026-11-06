//  PostmanURL+Template.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import PostmanKit

nonisolated extension PostmanURL {

    /// `raw` repeats the enabled rows of `query`, and `RequestBuilder` appends rows to a template's own query.
    var template: String {
        let address = raw ?? addressFromParts
        return query.isEmpty ? address : address.withoutQuery
    }

    private var addressFromParts: String {
        var address = host.joined(separator: ".")
        if let protocolName {
            address = "\(protocolName)://\(address)"
        }
        if let port {
            address += ":\(port)"
        }
        if !path.isEmpty {
            address += "/" + path.joined(separator: "/")
        }
        if let hash {
            address += "#\(hash)"
        }
        return address
    }

}

private nonisolated extension String {

    var withoutQuery: String {
        let fragmentStart = firstIndex(of: "#") ?? endIndex

        guard let queryStart = self[..<fragmentStart].firstIndex(of: "?") else {
            return self
        }

        return String(self[..<queryStart] + self[fragmentStart...])
    }

}
