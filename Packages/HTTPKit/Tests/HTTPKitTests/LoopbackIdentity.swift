//  LoopbackIdentity.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import Security

/// A self-signed certificate for 127.0.0.1 and localhost, made for these tests alone and trusted by nothing. It is
/// imported into memory only, so the test run never touches a keychain.
enum LoopbackIdentity {

    private static let passphrase = "moth-loopback"

    private static let pkcs12 = """
    MIIDqgIBAzCCA2gGCSqGSIb3DQEHAaCCA1kEggNVMIIDUTCCAkcGCSqGSIb3DQEHBqCCAjgwggI0AgEAMIICLQYJKoZIhvcNAQcB\
    MBwGCiqGSIb3DQEMAQYwDgQIzzkR0fJYVQECAggAgIICAJLb3onHVeuovn1nNTClcl503OjexC0RBaD4sS/foblOE8x6VOmiQGiU\
    EXhhXohzbMq1DzdgJR0Gjj7E5cvo0V60fd7+5rE30/8CwVcBBQafPyLNSPwEMclIbgc+uoNvuDp1NdlU65ucmlF8IUcOTj1WTLpa\
    W0c9jHJGWHCtLmlMh2q/YyZk69N9pdFw2lgy4lzGfK+ukc4DMxAKzawBdH4eGEj44MdUTKR49NDSTWJxU7Y5atkDeaMpZyB/34+o\
    W6Ag8zXhyih3KZYFpLrONNxpu/C0Sz3Bq9emcapDtkq5Ohw6bxC6MDSC9cvgfaXzwhBXBFzxf0CwS66E5rGzB+3LAbB1tsnhxGNn\
    +jHVHtEhFo7lKwRXZnQ/+dhx5WBDJiREaq+5XR2Om+f/U3MZVi1WzqUXbJzTWzcNJQ8GXRPJfexaSHvLyWQ3xFC7xFkLhsrrMXSy\
    lAbuo7SBz8uZJJhlJGtpi9N5TQ26PAl596NHoWb+H9dsiZbBU2gOLnQpQN0p0KrGFbiuB3yoBUgDyOsUyWLN8Zm5di3Qqv0jVaiZ\
    tfWoDOkMBFjh5EoG2uCh1Xt0LfYGK72cLYO9GRi+C7dMOBI6s6gTIa3BIeklAA4KrZuNj4TLGFG+JuDv85n61Dx7f525PteM3azx\
    /JU/n99qqdKP0miV/rbICgtOM0ugMIIBAgYJKoZIhvcNAQcBoIH0BIHxMIHuMIHrBgsqhkiG9w0BDAoBAqCBtDCBsTAcBgoqhkiG\
    9w0BDAEDMA4ECLrK/eea1cJIAgIIAASBkHb4J0KewA4NDvpgWxQIzHz3Sds5QIptb94BdrVa2MRYhO3DxoWMu4ik1B8ELL5bb6e8\
    skbD1gWy9ERoXwnid4TLxfbeztDMN9y2RrWhbtNGh5ixi8a+WgoQ6bl41tpqBD4mNnVSYf7oVqLKb5tqmgTifj2giEyWsN7JCE1H\
    2iI9TENWOUmB6SgwY6hxgh1pqTElMCMGCSqGSIb3DQEJFTEWBBSxI043ECjk2WJg0RubqlWCY5LxwzA5MCEwCQYFKw4DAhoFAAQU\
    bE4Q61phAN/x7+Ydx7Xph+thLJ8EEGOzHvOuucxG0NApiQlKSgACAggA
    """

    static func make() throws -> SecIdentity {
        guard let data = Data(base64Encoded: pkcs12) else {
            throw URLError(.cannotDecodeRawData)
        }
        let options = [kSecImportExportPassphrase: passphrase, kSecImportToMemoryOnly: true] as CFDictionary
        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options, &items)
        guard
            status == errSecSuccess,
            let item = (items as? [[String: Any]])?.first,
            let identity = item[kSecImportItemIdentity as String]
        else {
            throw URLError(.cannotDecodeRawData)
        }
        // swiftlint:disable:next force_cast
        return identity as! SecIdentity
    }

}
