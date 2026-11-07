//  AuthorizationSheet.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct AuthorizationSheet: View {

    @State private var model: AuthorizationModel
    @Environment(\.dismiss) private var dismiss
    private let accessTokens: AccessTokens
    private let tree: CollectionTree

    init(model: AuthorizationModel, accessTokens: AccessTokens = .preview, tree: CollectionTree = .empty) {
        self._model = State(initialValue: model)
        self.accessTokens = accessTokens
        self.tree = tree
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: model.target.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            AuthEditor(
                draft: model.draft,
                inherited: model.target.inherited,
                credential: model.credential,
                load: { await model.loadCredential($0) },
                update: { model.update($0) },
                accessToken: accessTokenControls
            )
            .disabled(model.isSaving)

            Spacer(minLength: 0)

            if model.saveFailed {
                Text("AUTHORIZATION_SAVE_FAILED")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("authorization.failed")
            }

            buttons
        }
        .padding()
        .frame(minWidth: 460, minHeight: 220)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("authorizationSheet")
    }

    private var buttons: some View {
        HStack {
            Spacer()

            Button("AUTHORIZATION_CANCEL") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("authorization.cancel")

            Button("AUTHORIZATION_SAVE", action: save)
                .keyboardShortcut(.defaultAction)
                .disabled(model.isSaving)
                .accessibilityIdentifier("authorization.save")
        }
    }

    /// The source is read when the button is pressed, so it carries what the sheet holds then.
    private var accessTokenControls: AccessTokenControls {
        accessTokens.controls(for: model.draft.oauth2.accessTokenReference) { [model, tree] in
            .container(model.target.container, model.draft, tree)
        }
    }

    private func save() {
        Task {
            if await model.save() {
                dismiss()
            }
        }
    }

}

#Preview {
    AuthorizationSheet(
        model: AuthorizationModel(
            target: AuthorizationSheetTarget(
                container: .folder(UUID()),
                title: "Users",
                auth: .basic(BasicAuth(username: "ada", password: SecretReference())),
                inherited: .from("Seeded Collection")
            ),
            secretStore: InMemorySecretStore(),
            write: { _, _ in [] }
        )
    )
}
