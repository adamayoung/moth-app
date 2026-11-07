//  OAuth2Auth+TokenReference.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CryptoKit
import Foundation

public nonisolated extension OAuth2Auth {

    /// A row stored before tokens had a reference gets one derived from its unresolved fields, so the editor, the
    /// sender and every request inheriting it agree on where its token is without the row being written.
    var tokenReference: SecretReference {
        if let accessToken {
            return accessToken
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let content = (try? encoder.encode(self)) ?? Data()
        return SecretReference(identifier: "oauth2-token-" + SHA256.hash(data: content).hexadecimal)
    }

}
