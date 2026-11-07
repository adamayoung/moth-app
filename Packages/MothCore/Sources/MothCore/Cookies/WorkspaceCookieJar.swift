//  WorkspaceCookieJar.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

/// One workspace's cookies, kept in the local store with their values in a device-only Keychain item. Never logs:
/// a cookie's value is a credential as often as not.
///
/// Memory changes at once, and the store and Keychain follow one change at a time, in order, because two sends
/// finish in no set order. A change that fails is not retried: the jar reads the store again on its next use. A
/// cookie whose value can't be saved stays in memory until quit, which is all an ad hoc build allows anyway.
public actor WorkspaceCookieJar: CookieJar {
    public nonisolated let workspaceID: UUID
    private let writer: StoreWriter
    private let secretStore: any SecretStore
    private let now: @Sendable () -> Date
    private var list = CookieList()
    private var rowIDs: [Cookie.Identity: UUID] = [:]
    private var loading: Task<Void, Never>?
    private var pending: Task<Void, Never>?

    init(
        workspaceID: UUID,
        writer: StoreWriter,
        secretStore: any SecretStore,
        seed: [Cookie]?,
        now: @escaping @Sendable () -> Date
    ) {
        self.workspaceID = workspaceID
        self.writer = writer
        self.secretStore = secretStore
        self.now = now
        if let seed {
            self.list = CookieList(seed)
            self.rowIDs = Dictionary(seed.map { ($0.identity, UUID()) }) { first, _ in first }
            self.loading = Task {}
        }
    }

    /// Every unexpired cookie, in the order they were set.
    public var all: [Cookie] {
        get async {
            await load()
            try? await persist(removing: records(releasing: list.removeExpired(at: now())))
            return list.cookies
        }
    }

    public func cookies(for url: URL) async -> [Cookie] {
        await load()
        return list.sending(to: url, at: now())
    }

    public func receive(_ cookies: [Cookie]) async {
        await load()
        let stamped = cookies.map { cookie in
            var cookie = cookie
            cookie.createdAt = now()
            return cookie
        }
        let change = list.receive(stamped, at: now())
        let saved = change.saved.map { CookieRecord(id: rowID(for: $0.identity), cookie: $0) }
        try? await persist(saving: saved, removing: records(releasing: change.removed))
    }

    public func delete(_ identities: Set<Cookie.Identity>) async throws {
        await load()
        try await persist(removing: records(releasing: list.remove { identities.contains($0.identity) }))
    }

    public func deleteAll() async throws {
        await load()
        try await persist(removing: records(releasing: list.remove { _ in true }))
    }

    private func rowID(for identity: Cookie.Identity) -> UUID {
        if let id = rowIDs[identity] {
            return id
        }
        let id = UUID()
        rowIDs[identity] = id
        return id
    }

    private func records(releasing cookies: [Cookie]) -> [CookieRecord] {
        cookies.compactMap { cookie in
            rowIDs.removeValue(forKey: cookie.identity).map { CookieRecord(id: $0, cookie: cookie) }
        }
    }

    private func load() async {
        if loading == nil {
            let previous = pending
            loading = Task {
                await previous?.value
                await read()
            }
        }
        await loading?.value
    }

    /// A row whose value is gone, as after an ad hoc build quits, is dropped, and so is a second row for one cookie.
    /// A row whose value can't be read keeps its identifier, so setting that cookie again replaces it.
    private func read() async {
        rowIDs = [:]
        list = CookieList()
        guard let rows = try? await writer.cookieRecords(in: workspaceID) else {
            loading = nil
            return
        }
        var found: [Cookie] = []
        var dropped: [CookieRecord] = []
        for record in rows {
            let identity = record.cookie.identity
            guard rowIDs[identity] == nil else {
                dropped.append(record)
                continue
            }
            let stored: String?
            do {
                stored = try await secretStore.value(for: record.valueIdentifier)
            } catch {
                rowIDs[identity] = record.id
                continue
            }
            guard let value = stored else {
                dropped.append(record)
                continue
            }
            var cookie = record.cookie
            cookie.value = value
            found.append(cookie)
            rowIDs[identity] = record.id
        }
        list = CookieList(found)
        try? await persist(removing: dropped + records(releasing: list.removeExpired(at: now())))
    }

    private func persist(saving: [CookieRecord] = [], removing: [CookieRecord] = []) async throws {
        guard !saving.isEmpty || !removing.isEmpty else {
            return
        }
        let previous = pending
        let change = CookieStoreChange(
            workspaceID: workspaceID,
            writer: writer,
            secretStore: secretStore,
            saving: saving,
            removing: removing
        )
        let applying = Task {
            await previous?.value
            return await change.apply()
        }
        pending = Task { _ = await applying.value }
        if case .failure(let error) = await applying.value {
            loading = nil
            throw error
        }
    }
}

/// Rows are written before values and removed after them, because a row whose value is missing is dropped at the next
/// load, while a value with no row would stay in the Keychain for good.
private nonisolated struct CookieStoreChange: Sendable {
    let workspaceID: UUID
    let writer: StoreWriter
    let secretStore: any SecretStore
    let saving: [CookieRecord]
    let removing: [CookieRecord]

    func apply() async -> Result<Void, any Error> {
        var failure: any Error?
        do {
            try await writer.saveCookies(saving, in: workspaceID)
            for record in saving {
                do {
                    try await secretStore.save(record.cookie.value, for: record.valueIdentifier)
                } catch {
                    failure = failure ?? error
                }
            }
        } catch {
            failure = error
        }
        let removed = await CookieValues.remove(removing, from: secretStore)
        do {
            try await writer.removeCookies(removed.ids)
        } catch {
            failure = failure ?? error
        }
        if let error = failure ?? removed.failure {
            return .failure(error)
        }
        return .success(())
    }
}
