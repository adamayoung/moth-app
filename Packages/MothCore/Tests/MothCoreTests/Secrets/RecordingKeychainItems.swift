//  RecordingKeychainItems.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import Security
import Synchronization

final nonisolated class RecordingKeychainItems: KeychainItems {

    private struct Attributes: @unchecked Sendable {
        var value: [CFString: Any]?
    }

    private let addStatus: OSStatus
    private let updateStatus: OSStatus
    private let readStatus: OSStatus
    private let readData: Data?
    private let deleteStatus: OSStatus

    private let added = Mutex(Attributes())
    private let updated = Mutex(Attributes())
    private let read = Mutex(Attributes())
    private let deleted = Mutex(Attributes())

    init(
        addStatus: OSStatus = errSecSuccess,
        updateStatus: OSStatus = errSecSuccess,
        readStatus: OSStatus = errSecSuccess,
        readData: Data? = nil,
        deleteStatus: OSStatus = errSecSuccess
    ) {
        self.addStatus = addStatus
        self.updateStatus = updateStatus
        self.readStatus = readStatus
        self.readData = readData
        self.deleteStatus = deleteStatus
    }

    var addedAttributes: [CFString: Any]? {
        added.withLock { $0.value }
    }

    var updateQuery: [CFString: Any]? {
        updated.withLock { $0.value }
    }

    var readQuery: [CFString: Any]? {
        read.withLock { $0.value }
    }

    var deleteQuery: [CFString: Any]? {
        deleted.withLock { $0.value }
    }

    func add(_ attributes: [CFString: Any]) -> OSStatus {
        added.withLock { $0.value = attributes }
        return addStatus
    }

    func update(_ query: [CFString: Any], changes: [CFString: Any]) -> OSStatus {
        updated.withLock { $0.value = query }
        return updateStatus
    }

    func copyData(_ query: [CFString: Any]) -> (status: OSStatus, data: Data?) {
        read.withLock { $0.value = query }
        return (readStatus, readData)
    }

    func delete(_ query: [CFString: Any]) -> OSStatus {
        deleted.withLock { $0.value = query }
        return deleteStatus
    }

}
