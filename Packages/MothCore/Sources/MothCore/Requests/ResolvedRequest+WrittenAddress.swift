//  ResolvedRequest+WrittenAddress.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// `value` goes in as given, so a placeholder stays readable.
public nonisolated struct LiteralQueryPair: Sendable, Hashable {

    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

}

public nonisolated extension ResolvedRequest {

    /// The URL as text to read and fill in, because a `{{variable}}` left in it makes it no URL for
    /// `sendableAddress()`.
    func writtenAddress(settingQuery pair: LiteralQueryPair? = nil) -> String {
        let text = URLTemplateText(url)
        return Self.withWrittenScheme(text.addressFillingPathVariables(from: pathParameters))
            + text.queryAndFragment(appending: queryParameters, setting: pair)
    }

    /// A leading variable may hold the scheme, and `name:{{port}}` is a host, not a scheme with no digits after it.
    private static func withWrittenScheme(_ address: String) -> String {
        if address.isEmpty || address.hasPrefix("{{") {
            return address
        }
        return address.prefixMatch(of: /[A-Za-z][A-Za-z0-9+.\-]*:\{\{/) == nil ? withScheme(address) : "http://\(address)"
    }

}
