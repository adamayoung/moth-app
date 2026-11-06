//  AuthorizationModel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import Observation
import OSLog

/// The sheet edits a value draft and writes it once, on Save, so credentials reach the store the way a request's do.
@Observable
final class AuthorizationModel {

    /// Takes the auth to store and the auth the sheet read, and returns the references the write leaves unheld.
    typealias Write = @MainActor (Auth, Auth) async throws -> Set<SecretReference>

    let target: AuthorizationSheetTarget
    private(set) var draft: AuthDraft
    private(set) var isSaving = false
    private(set) var saveFailed = false
    private var credentials = StoredCredentials()

    private let secretStore: any SecretStore
    private let write: Write

    init(target: AuthorizationSheetTarget, secretStore: any SecretStore, write: @escaping Write) {
        self.target = target
        self.draft = AuthDraft(target.auth)
        self.secretStore = secretStore
        self.write = write
    }

    func update(_ change: (inout AuthDraft) -> Void) {
        change(&draft)
        draft.discardCredentials(matching: credentials, heldBy: target.auth)
    }

    func credential(_ reference: SecretReference) -> SecretValue {
        credentials.value(of: reference, heldBy: target.auth)
    }

    func loadCredential(_ reference: SecretReference) async {
        guard target.auth.secretReferences.contains(reference) else {
            return
        }
        await credentials.record(secretStore.credential(reference), for: reference)
        draft.discardCredentials(matching: credentials, heldBy: target.auth)
    }

    /// Returns whether the sheet can close. Values go first, because a row referring to no value would lose it.
    func save() async -> Bool {
        guard !isSaving else {
            return false
        }
        guard !draft.hasSameContent(as: AuthDraft(target.auth)) else {
            return true
        }
        isSaving = true
        saveFailed = false
        defer {
            isSaving = false
        }
        do {
            for write in draft.credentialWrites(heldBy: target.auth) {
                try await secretStore.apply(write)
                credentials.record(write.value, for: write.reference)
            }
            let released = try await write(draft.requestAuth, target.auth)
            await secretStore.remove(released)
            return true
        } catch {
            Logger.sidebar.error("Saving auth failed: \(String(describing: error), privacy: .private)")
            saveFailed = true
            return false
        }
    }

}
