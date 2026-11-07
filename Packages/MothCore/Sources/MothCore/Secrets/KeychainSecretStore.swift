//  KeychainSecretStore.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import Security

public nonisolated struct KeychainSecretStore: SecretStore {

    public enum Mode: Sendable, Equatable {
        /// The login keychain, because the data protection keychain needs an entitlement that only comes with iCloud.
        /// Its items answer to the signing identity: an ad hoc rebuild prompts for a password on read, and any rebuild
        /// fails with `errSecInvalidOwnerEdit` removing an item an earlier build saved.
        case localOnly
        case synchronised(accessGroup: String)
        /// For what belongs to one Mac, such as a session cookie. A synchronisable item can't be `ThisDeviceOnly`.
        case deviceOnly(accessGroup: String)
    }

    public let service: String
    public let mode: Mode
    private let keychain: any KeychainItems

    public init(service: String, mode: Mode) {
        self.init(service: service, mode: mode, keychain: SystemKeychainItems())
    }

    init(service: String, mode: Mode, keychain: any KeychainItems) {
        self.service = service
        self.mode = mode
        self.keychain = keychain
    }

    @concurrent
    public func save(_ value: String, for identifier: String) async throws {
        let query = query(for: identifier)
        let data = Data(value.utf8)
        var attributes = query
        attributes[kSecValueData] = data
        switch mode {
        case .localOnly:
            break
        case .synchronised:
            attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
        case .deviceOnly:
            attributes[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }

        var status = keychain.add(attributes)
        if status == errSecDuplicateItem {
            status = keychain.update(query, changes: [kSecValueData: data])
        }
        guard status == errSecSuccess else {
            throw KeychainSecretStoreError(operation: .save, status: status)
        }
    }

    @concurrent
    public func value(for identifier: String) async throws -> String? {
        var query = query(for: identifier)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        let result = keychain.copyData(query)
        switch result.status {
        case errSecSuccess:
            guard let data = result.data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainSecretStoreError(operation: .read, status: errSecDecode)
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainSecretStoreError(operation: .read, status: result.status)
        }
    }

    @concurrent
    public func removeValue(for identifier: String) async throws {
        let status = keychain.delete(query(for: identifier))
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretStoreError(operation: .remove, status: status)
        }
    }

    private func query(for identifier: String) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: identifier
        ]
        switch mode {
        case .localOnly:
            query[kSecAttrSynchronizable] = false
        case .synchronised(let accessGroup):
            query[kSecAttrSynchronizable] = true
            query[kSecAttrAccessGroup] = accessGroup
            query[kSecUseDataProtectionKeychain] = true
        case .deviceOnly(let accessGroup):
            query[kSecAttrSynchronizable] = false
            query[kSecAttrAccessGroup] = accessGroup
            query[kSecUseDataProtectionKeychain] = true
        }
        return query
    }

}
