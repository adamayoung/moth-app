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
        .task(id: draft.credentialReferences) {
            for reference in draft.credentialReferences {
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
        case .awsSigV4:
            awsSigV4Fields
        case .apiKey:
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("AUTH_API_KEY_NAME")
                    TextField("AUTH_API_KEY_NAME", text: apiKeyName)
                        .labelsHidden()
                        .accessibilityIdentifier("auth.apiKeyName")
                }
                GridRow {
                    Text("AUTH_API_KEY_VALUE")
                    credentialField(
                        "AUTH_API_KEY_VALUE",
                        identifier: "auth.apiKeyValue",
                        for: draft.apiKeyValueReference
                    )
                }
                GridRow {
                    Text("AUTH_API_KEY_ADD_TO")
                    Picker("AUTH_API_KEY_ADD_TO", selection: apiKeyLocation) {
                        Text("AUTH_API_KEY_LOCATION_HEADER").tag(APIKeyLocation.header)
                        Text("AUTH_API_KEY_LOCATION_QUERY").tag(APIKeyLocation.query)
                    }
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("auth.apiKeyLocation")
                }
            }
        case .digest, .oauth2:
            Text("NOT_SUPPORTED_YET")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("auth.notSupported")
        }
    }

    private var awsSigV4Fields: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("AUTH_ACCESS_KEY")
                credentialField(
                    "AUTH_ACCESS_KEY",
                    identifier: "auth.accessKey",
                    for: draft.awsSigV4.accessKeyReference,
                    isConcealed: false
                )
            }
            GridRow {
                Text("AUTH_SECRET_KEY")
                credentialField("AUTH_SECRET_KEY", identifier: "auth.secretKey", for: draft.awsSigV4.secretKeyReference)
            }
            GridRow {
                Text("AUTH_SESSION_TOKEN")
                credentialField(
                    "AUTH_SESSION_TOKEN",
                    identifier: "auth.sessionToken",
                    for: draft.awsSigV4.sessionTokenReference
                )
            }
            GridRow {
                Text("AUTH_REGION")
                TextField("AUTH_REGION", text: awsField(\.region))
                    .labelsHidden()
                    .accessibilityIdentifier("auth.region")
            }
            GridRow {
                Text("AUTH_SERVICE")
                TextField("AUTH_SERVICE", text: awsField(\.service))
                    .labelsHidden()
                    .accessibilityIdentifier("auth.service")
            }
        }
    }

    private func credentialField(
        _ label: LocalizedStringKey,
        identifier: String,
        for reference: SecretReference,
        isConcealed: Bool = true
    ) -> some View {
        let value = credential(reference)
        return CredentialField(
            label: label,
            identifier: identifier,
            isConcealed: isConcealed,
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

    private func awsField(_ field: WritableKeyPath<AWSSigV4Draft, String>) -> Binding<String> {
        Binding {
            draft.awsSigV4[keyPath: field]
        } set: { text in
            update { $0.awsSigV4[keyPath: field] = text }
        }
    }

    private var apiKeyName: Binding<String> {
        Binding {
            draft.apiKeyName
        } set: { name in
            update { $0.apiKeyName = name }
        }
    }

    private var apiKeyLocation: Binding<APIKeyLocation> {
        Binding {
            draft.apiKeyLocation
        } set: { location in
            update { $0.apiKeyLocation = location }
        }
    }

}

private struct AuthEditorPreview: View {

    @State var draft: AuthDraft
    var inherited = InheritedAuth.nothing
    var value = SecretValue.available("hunter2")
    var height: CGFloat = 160

    var body: some View {
        AuthEditor(
            draft: draft,
            inherited: inherited,
            credential: { _ in value },
            load: { _ in },
            update: { change in change(&draft) }
        )
        .padding()
        .frame(width: 480, height: height, alignment: .top)
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

#Preview("AWS Signature") {
    AuthEditorPreview(
        draft: AuthDraft(.awsSigV4(AWSSigV4Auth(
            accessKeyID: SecretReference(),
            secretAccessKey: SecretReference(),
            region: "eu-west-2",
            service: "execute-api"
        ))),
        height: 220
    )
}

#Preview("API Key") {
    AuthEditorPreview(draft: AuthDraft(.apiKey(APIKeyAuth(
        name: "X-API-Key",
        value: SecretReference(),
        location: .query
    ))))
}

#Preview("Not Supported") {
    AuthEditorPreview(draft: AuthDraft(.digest(DigestAuth(username: "ada", password: SecretReference()))))
}
