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
    /// Kept, not rebuilt from `target`, because a draft mints an OAuth 2.0 token reference the row may not hold.
    private let opened: AuthDraft
    private(set) var isSaving = false
    private(set) var saveFailed = false
    private var credentials = StoredCredentials()

    private let secretStore: any SecretStore
    private let write: Write

    init(target: AuthorizationSheetTarget, secretStore: any SecretStore, write: @escaping Write) {
        self.target = target
        let opened = AuthDraft(target.auth)
        self.draft = opened
        self.opened = opened
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

    /// Returns whether the sheet can close. Stays saving once it has worked, because the row has moved on from what
    /// this
    /// sheet read, and a second Save would be refused and take the value the row now holds with it.
    func save() async -> Bool {
        guard !isSaving else {
            return false
        }
        guard !draft.hasSameContent(as: opened) else {
            return true
        }
        isSaving = true
        saveFailed = false
        let auth = draft.requestAuth
        do {
            _ = try await secretStore.commit(draft.credentialWrites()) {
                try await write(auth, target.auth)
            }
            return true
        } catch {
            Logger.sidebar.error("Saving auth failed: \(String(describing: error), privacy: .private)")
            isSaving = false
            saveFailed = true
            return false
        }
    }

}
