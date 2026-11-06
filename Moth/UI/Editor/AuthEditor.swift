//  AuthEditor.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

struct AuthEditor: View {

    let draft: AuthDraft
    let inherited: InheritedAuth
    let credential: (SecretReference) -> SecretValue
    let load: (SecretReference) async -> Void
    let update: ((inout AuthDraft) -> Void) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("AUTH_KIND_LABEL", selection: kind) {
                ForEach(draft.kinds, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("auth.kind")

            fields
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: draft.credentialReference) {
            if let reference = draft.credentialReference {
                await load(reference)
            }
        }
    }

    @ViewBuilder
    private var fields: some View {
        switch draft.kind {
        case .inherit:
            Text(verbatim: inherited.message)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("auth.inherited")
        case .none:
            EmptyView()
        case .basic:
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("AUTH_USERNAME")
                    TextField("AUTH_USERNAME", text: username)
                        .labelsHidden()
                        .accessibilityIdentifier("auth.username")
                }
                GridRow {
                    Text("AUTH_PASSWORD")
                    credentialField("AUTH_PASSWORD", identifier: "auth.password", for: draft.passwordReference)
                }
            }
        case .bearer:
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("AUTH_TOKEN")
                    credentialField("AUTH_TOKEN", identifier: "auth.token", for: draft.tokenReference)
                }
            }
        case .apiKey, .digest, .oauth2, .awsSigV4:
            Text("NOT_SUPPORTED_YET")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("auth.notSupported")
        }
    }

    private func credentialField(
        _ label: LocalizedStringKey,
        identifier: String,
        for reference: SecretReference
    ) -> some View {
        let value = credential(reference)
        return CredentialField(
            label: label,
            identifier: identifier,
            value: value,
            text: Binding {
                draft.typedCredential(for: reference) ?? value.text
            } set: { text in
                update { $0.setCredential(text, for: reference) }
            }
        )
    }

    private var kind: Binding<AuthKind> {
        Binding {
            draft.kind
        } set: { kind in
            update { $0.kind = kind }
        }
    }

    private var username: Binding<String> {
        Binding {
            draft.username
        } set: { username in
            update { $0.username = username }
        }
    }

}

private struct AuthEditorPreview: View {

    @State var draft: AuthDraft
    var inherited = InheritedAuth.nothing
    var value = SecretValue.available("hunter2")

    var body: some View {
        AuthEditor(
            draft: draft,
            inherited: inherited,
            credential: { _ in value },
            load: { _ in },
            update: { change in change(&draft) }
        )
        .padding()
        .frame(width: 480, height: 160, alignment: .top)
    }

}

#Preview("Inherited") {
    AuthEditorPreview(draft: AuthDraft(.inherit), inherited: .from("Users"))
}

#Preview("Basic") {
    AuthEditorPreview(draft: AuthDraft(.basic(BasicAuth(username: "ada", password: SecretReference()))))
}

#Preview("Bearer, Not Yet Available") {
    AuthEditorPreview(draft: AuthDraft(.bearer(BearerAuth(token: SecretReference()))), value: .notYetAvailable)
}

#Preview("Not Supported") {
    AuthEditorPreview(draft: AuthDraft(.digest(DigestAuth(username: "ada", password: SecretReference()))))
}
