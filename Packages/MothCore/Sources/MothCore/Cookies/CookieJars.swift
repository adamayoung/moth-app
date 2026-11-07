//  CookieJars.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

/// A jar for each workspace, one for the app, so every window sends with the same cookies.
public final class CookieJars {

    private let writer: StoreWriter
    private let secretStore: any SecretStore
    private let now: @Sendable () -> Date
    private var seed: [UUID: [Cookie]]
    private var jars: [UUID: WorkspaceCookieJar] = [:]

    public init(
        writer: StoreWriter,
        secretStore: any SecretStore,
        seed: [UUID: [Cookie]] = [:],
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.writer = writer
        self.secretStore = secretStore
        self.seed = seed
        self.now = now
    }

    public func jar(for workspaceID: UUID) -> WorkspaceCookieJar {
        if let jar = jars[workspaceID] {
            return jar
        }
        let jar = WorkspaceCookieJar(
            workspaceID: workspaceID,
            writer: writer,
            secretStore: secretStore,
            seed: seed.removeValue(forKey: workspaceID),
            now: now
        )
        jars[workspaceID] = jar
        return jar
    }

    /// Run after the launch reconcile, which deletes a merged-away workspace and so its cookies.
    /// A row stays for each value that won't go, so the next launch tries again.
    public func removeCookiesOfDeletedWorkspaces() async throws {
        let removal = try await CookieValues.remove(
            writer.cookieRecordsOfDeletedWorkspaces().map(\.id),
            from: secretStore
        )
        try await writer.removeCookies(removal.ids)
        if let failure = removal.failure {
            throw failure
        }
    }

}
