//  AppSignature.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import Security

struct AppSignature: Equatable {

    let teamIdentifier: String?
    let keychainAccessGroup: String?

    init(teamIdentifier: String?, keychainAccessGroup: String?) {
        self.teamIdentifier = teamIdentifier
        self.keychainAccessGroup = keychainAccessGroup
    }

    init(signingInformation: [String: Any]) {
        let entitlements = signingInformation[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        let accessGroups = entitlements?["keychain-access-groups"] as? [String]
        self.init(
            teamIdentifier: signingInformation[kSecCodeInfoTeamIdentifier as String] as? String,
            keychainAccessGroup: accessGroups?.first
        )
    }

    /// A signature that cannot be read counts as ad hoc, the mode that needs nothing from the Keychain.
    static func current() -> AppSignature {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        guard
            SecCodeCopySelf([], &code) == errSecSuccess,
            let code,
            SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
            let staticCode,
            SecCodeCopySigningInformation(
                staticCode,
                SecCSFlags(rawValue: kSecCSSigningInformation | kSecCSRequirementInformation),
                &information
            ) == errSecSuccess
        else {
            return AppSignature(signingInformation: [:])
        }
        return AppSignature(signingInformation: information as? [String: Any] ?? [:])
    }

}
