//  KeychainItems.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import Security

nonisolated protocol KeychainItems: Sendable {

    func add(_ attributes: [CFString: Any]) -> OSStatus

    func update(_ query: [CFString: Any], changes: [CFString: Any]) -> OSStatus

    func copyData(_ query: [CFString: Any]) -> (status: OSStatus, data: Data?)

    func delete(_ query: [CFString: Any]) -> OSStatus

}

nonisolated struct SystemKeychainItems: KeychainItems {

    func add(_ attributes: [CFString: Any]) -> OSStatus {
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func update(_ query: [CFString: Any], changes: [CFString: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, changes as CFDictionary)
    }

    func copyData(_ query: [CFString: Any]) -> (status: OSStatus, data: Data?) {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }

    func delete(_ query: [CFString: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }

}
