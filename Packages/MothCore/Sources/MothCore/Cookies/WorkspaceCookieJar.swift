//  WorkspaceCookieJar.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

/// One workspace's cookies, kept in the local store with their values in a device-only Keychain item. Never logs:
/// a cookie's value is a credential as often as not.
///
/// Storing is best effort: a cookie whose value can't be saved stays in memory until quit, which is all an ad hoc
/// build's in-memory secret store allows anyway.
public actor WorkspaceCookieJar: CookieJar {

    public nonisolated let workspaceID: UUID
    private let writer: StoreWriter
    private let secretStore: any SecretStore
    private let now: @Sendable () -> Date
    private var list = CookieList()
    private var rowIDs: [Cookie.Identity: UUID] = [:]
    private var loading: Task<Void, Never>?

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
            await forget(list.removeExpired(at: now()))
            return list.cookies
        }
    }

    public func cookies(for url: URL) async -> [Cookie] {
        await load()
        return list.sending(to: url, at: now())
    }

    public func receive(_ cookies: [Cookie]) async {
        await load()
        let change = list.receive(cookies, at: now())
        let saved = change.saved.map { cookie in
            CookieRecord(id: rowID(for: cookie.identity), cookie: cookie)
        }
        await forget(change.removed)
        await store(saved)
    }

    public func delete(_ identities: Set<Cookie.Identity>) async throws {
        await load()
        try await remove(list.remove { identities.contains($0.identity) })
    }

    public func deleteAll() async throws {
        await load()
        try await remove(list.remove { _ in true })
    }

    private func rowID(for identity: Cookie.Identity) -> UUID {
        if let id = rowIDs[identity] {
            return id
        }
        let id = UUID()
        rowIDs[identity] = id
        return id
    }

    private func load() async {
        if loading == nil {
            loading = Task { await read() }
        }
        await loading?.value
    }

    /// A row whose value is missing is dropped, as after an ad hoc build's in-memory secrets are gone.
    private func read() async {
        guard let records = try? await writer.cookieRecords(in: workspaceID) else {
            return
        }
        var found: [Cookie] = []
        var missing: [UUID] = []
        for record in records {
            let stored: String?
            do {
                stored = try await secretStore.value(for: record.valueIdentifier)
            } catch {
                continue
            }
            guard let value = stored else {
                missing.append(record.id)
                continue
            }
            var cookie = record.cookie
            cookie.value = value
            found.append(cookie)
            rowIDs[cookie.identity] = record.id
        }
        try? await writer.removeCookies(missing)
        list = CookieList(found)
        await forget(list.removeExpired(at: now()))
    }

    private func store(_ records: [CookieRecord]) async {
        var saved: [CookieRecord] = []
        for record in records {
            if await (try? secretStore.save(record.cookie.value, for: record.valueIdentifier)) != nil {
                saved.append(record)
            }
        }
        try? await writer.saveCookies(saved, in: workspaceID)
    }

    private func forget(_ cookies: [Cookie]) async {
        try? await remove(cookies)
    }

    /// The rows go first, because a row whose value is gone is dropped at the next load anyway.
    private func remove(_ cookies: [Cookie]) async throws {
        let records = cookies.compactMap { cookie in
            rowIDs.removeValue(forKey: cookie.identity).map { CookieRecord(id: $0, cookie: cookie) }
        }
        guard !records.isEmpty else {
            return
        }
        try await writer.removeCookies(records.map(\.id))
        for record in records {
            try await secretStore.removeValue(for: record.valueIdentifier)
        }
    }

}
