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
    private var isLoaded = false

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
            self.isLoaded = true
        }
    }

    /// Every unexpired cookie, in the order they were set.
    public var all: [Cookie] {
        get async {
            await load()
            try? await persist(removing: rowIDs(releasing: list.removeExpired(at: now())), reloadsOnFailure: false)
            return list.cookies
        }
    }

    public func cookies(for url: URL) async -> [Cookie] {
        await load()
        return list.sending(to: url, at: now())
    }

    /// A failure here leaves memory as it is, so a cookie whose value can't be saved is still sent until quit.
    public func receive(_ cookies: [Cookie], from url: URL) async {
        await load()
        let change = list.receive(cookies, at: now(), overSecureScheme: url.isSecureScheme)
        let saved = change.saved.map { CookieRecord(id: rowID(for: $0.identity), cookie: $0) }
        try? await persist(saving: saved, removing: rowIDs(releasing: change.removed), reloadsOnFailure: false)
    }

    public func delete(_ identities: Set<Cookie.Identity>) async throws {
        try await loadForDeleting()
        try await persist(removing: rowIDs(releasing: list.remove { identities.contains($0.identity) }))
    }

    /// Reaches a row whose value couldn't be read too, which the list doesn't hold.
    public func deleteAll() async throws {
        try await loadForDeleting()
        list.remove { _ in true }
        let ids = Array(rowIDs.values)
        rowIDs = [:]
        try await persist(removing: ids)
    }

    private func rowID(for identity: Cookie.Identity) -> UUID {
        if let id = rowIDs[identity] {
            return id
        }
        let id = UUID()
        rowIDs[identity] = id
        return id
    }

    private func rowIDs(releasing cookies: [Cookie]) -> [UUID] {
        cookies.compactMap { rowIDs.removeValue(forKey: $0.identity) }
    }

    /// A delete with no rows read would remove nothing and report success.
    private func loadForDeleting() async throws {
        await load()
        guard isLoaded else {
            throw CocoaError(.fileReadUnknown)
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

    /// A row whose value is gone, as after an ad hoc build quits, is dropped, and so is an older row for one cookie.
    /// A row whose value can't be read keeps its identifier, so setting that cookie again replaces it. A store that
    /// can't be read leaves memory as it was, and the next use tries again.
    private func read() async {
        guard let rows = try? await writer.cookieRecords(in: workspaceID) else {
            loading = nil
            return
        }
        rowIDs = [:]
        list = CookieList()
        let oldestFirst = rows.sorted { $0.cookie.createdAt < $1.cookie.createdAt }
        var newest: [Cookie.Identity: UUID] = [:]
        var dropped: [UUID] = []
        for record in oldestFirst {
            if let older = newest.updateValue(record.id, forKey: record.cookie.identity) {
                dropped.append(older)
            }
        }
        var found: [Cookie] = []
        for record in oldestFirst where newest[record.cookie.identity] == record.id {
            let identity = record.cookie.identity
            let stored: String?
            do {
                stored = try await secretStore.value(for: record.valueIdentifier)
            } catch {
                rowIDs[identity] = record.id
                continue
            }
            guard let value = stored else {
                dropped.append(record.id)
                continue
            }
            var cookie = record.cookie
            cookie.value = value
            found.append(cookie)
            rowIDs[identity] = record.id
        }
        list = CookieList(found)
        isLoaded = true
        try? await persist(
            removing: dropped + rowIDs(releasing: list.removeExpired(at: now())),
            reloadsOnFailure: false
        )
    }

    /// A failed change makes the jar read the store again on its next use, unless the caller keeps memory as it is.
    private func persist(
        saving: [CookieRecord] = [],
        removing: [UUID] = [],
        reloadsOnFailure: Bool = true
    ) async throws {
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
            if reloadsOnFailure {
                loading = nil
            }
            throw error
        }
    }
}

/// Rows are written before values and removed after them, because a row whose value is missing is dropped at the next
/// load, while a value with no row would stay in the Keychain for good. A row whose new value can't be saved goes, so
/// its old value can't come back.
private nonisolated struct CookieStoreChange: Sendable {
    let workspaceID: UUID
    let writer: StoreWriter
    let secretStore: any SecretStore
    let saving: [CookieRecord]
    let removing: [UUID]

    func apply() async -> Result<Void, any Error> {
        var failure: any Error?
        var unsaved: [UUID] = []
        do {
            try await writer.saveCookies(saving, in: workspaceID)
            for record in saving {
                do {
                    try await secretStore.save(record.cookie.value, for: record.valueIdentifier)
                } catch {
                    unsaved.append(record.id)
                    failure = failure ?? error
                }
            }
        } catch {
            failure = error
        }
        let removed = await CookieValues.remove(removing + unsaved, from: secretStore)
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
