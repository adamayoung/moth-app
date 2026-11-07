//  URL+Origin.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public extension URL {

    /// Scheme, host and port, with the scheme's default port filled in.
    func hasSameOrigin(as other: URL?) -> Bool {
        guard let other, let origin, let otherOrigin = other.origin else {
            return false
        }
        return origin == otherOrigin
    }

    private var origin: String? {
        guard let scheme = scheme?.lowercased(), let host = host()?.lowercased() else {
            return nil
        }
        return "\(scheme)://\(host):\(port ?? HTTPDefaultPort.of(scheme: scheme) ?? -1)"
    }

}
