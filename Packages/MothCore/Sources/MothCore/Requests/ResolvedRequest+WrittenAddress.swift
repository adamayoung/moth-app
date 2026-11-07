//  ResolvedRequest+WrittenAddress.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated extension ResolvedRequest {

    /// The URL as text to read and fill in, because a `{{variable}}` left in it makes it no URL for
    /// `sendableAddress()`. `addingQuery` goes in as given, so a placeholder stays readable.
    func writtenAddress(addingQuery literalPair: String? = nil) -> String {
        let text = URLTemplateText(url)
        let address = text.addressFillingPathVariables(from: pathParameters)
        let tail = text.queryAndFragment(appending: queryParameters, then: literalPair)
        let mayHoldItsScheme = address.isEmpty || address.hasPrefix("{{")
        return (mayHoldItsScheme ? address : Self.withScheme(address)) + tail
    }

}
