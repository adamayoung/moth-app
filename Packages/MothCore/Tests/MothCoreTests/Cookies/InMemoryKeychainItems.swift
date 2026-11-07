//  InMemoryKeychainItems.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import Security
import Synchronization

/// Keeps items by account, so a new `KeychainSecretStore` over the same items stands in for a relaunch.
final nonisolated class InMemoryKeychainItems: KeychainItems {

    private struct Item: @unchecked Sendable {
        var attributes: [CFString: Any]
    }

    private let items = Mutex<[String: Item]>([:])

    var accounts: Set<String> {
        items.withLock { Set($0.keys) }
    }

    func attributes(of account: String) -> [CFString: Any]? {
        items.withLock { $0[account]?.attributes }
    }

    func add(_ attributes: [CFString: Any]) -> OSStatus {
        guard let account = attributes[kSecAttrAccount] as? String else {
            return errSecParam
        }
        return items.withLock { items in
            guard items[account] == nil else {
                return errSecDuplicateItem
            }
            items[account] = Item(attributes: attributes)
            return errSecSuccess
        }
    }

    func update(_ query: [CFString: Any], changes: [CFString: Any]) -> OSStatus {
        guard let account = query[kSecAttrAccount] as? String else {
            return errSecParam
        }
        return items.withLock { items in
            guard var item = items[account] else {
                return errSecItemNotFound
            }
            item.attributes.merge(changes) { _, new in new }
            items[account] = item
            return errSecSuccess
        }
    }

    func copyData(_ query: [CFString: Any]) -> (status: OSStatus, data: Data?) {
        guard let account = query[kSecAttrAccount] as? String,
              let data = attributes(of: account)?[kSecValueData] as? Data
        else {
            return (errSecItemNotFound, nil)
        }
        return (errSecSuccess, data)
    }

    func delete(_ query: [CFString: Any]) -> OSStatus {
        guard let account = query[kSecAttrAccount] as? String else {
            return errSecParam
        }
        return items.withLock { $0.removeValue(forKey: account) == nil ? errSecItemNotFound : errSecSuccess }
    }

}
