//  AuthEditor+OAuth2.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftUI

/// What the OAuth 2.0 pane shows of its token, and what its buttons do. The default shows No Token and does nothing,
/// for a preview.
struct AccessTokenControls {

    var status = AccessTokens.Status.none
    var isFetching = false
    var failure: String?
    var load: () async -> Void = {}
    var getNew: () -> Void = {}
    var clear: () -> Void = {}

}

extension AccessTokens {

    func controls(for reference: SecretReference, source: @escaping () -> Source) -> AccessTokenControls {
        AccessTokenControls(
            status: status(of: reference),
            isFetching: isFetching(reference),
            failure: failure(of: reference),
            load: { await self.load(reference) },
            getNew: { Task { await self.getNewToken(for: reference, from: source()) } },
            clear: { Task { await self.clear(reference) } }
        )
    }

}

extension AuthEditor {

    var oauth2Fields: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("AUTH_OAUTH2_GRANT_TYPE")
                Picker("AUTH_OAUTH2_GRANT_TYPE", selection: oauth2Field(\.grantType)) {
                    ForEach(draft.oauth2.grantTypes, id: \.self) { grantType in
                        Text(grantType.title).tag(grantType)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("auth.grantType")
            }
            if draft.oauth2.isSupported {
                clientCredentialsRows
            } else {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    Text("NOT_SUPPORTED_YET")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("auth.notSupported")
                }
            }
        }
        .task(id: draft.oauth2.accessTokenReference) {
            await accessToken.load()
        }
    }

    @ViewBuilder
    private var clientCredentialsRows: some View {
        GridRow {
            Text("AUTH_OAUTH2_TOKEN_URL")
            TextField("AUTH_OAUTH2_TOKEN_URL", text: oauth2Field(\.tokenURL))
                .labelsHidden()
                .accessibilityIdentifier("auth.tokenURL")
        }
        GridRow {
            Text("AUTH_OAUTH2_CLIENT_ID")
            TextField("AUTH_OAUTH2_CLIENT_ID", text: oauth2Field(\.clientID))
                .labelsHidden()
                .accessibilityIdentifier("auth.clientID")
        }
        GridRow {
            Text("AUTH_OAUTH2_CLIENT_SECRET")
            credentialField(
                "AUTH_OAUTH2_CLIENT_SECRET",
                identifier: "auth.clientSecret",
                for: draft.oauth2.clientSecretReference
            )
        }
        GridRow {
            Text("AUTH_OAUTH2_SCOPE")
            TextField("AUTH_OAUTH2_SCOPE", text: oauth2Field(\.scope), prompt: Text("AUTH_OAUTH2_SCOPE_PROMPT"))
                .labelsHidden()
                .accessibilityIdentifier("auth.scope")
        }
        GridRow {
            Text("AUTH_OAUTH2_ACCESS_TOKEN")
            TimelineView(.everyMinute) { context in
                tokenStatus(at: context.date)
                    .accessibilityIdentifier("auth.tokenState")
            }
        }
        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            tokenActions
        }
    }

    private var tokenActions: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button("AUTH_OAUTH2_GET_NEW_TOKEN", action: accessToken.getNew)
                    .disabled(accessToken.isFetching)
                    .accessibilityIdentifier("auth.getNewToken")
                Button("AUTH_OAUTH2_CLEAR_TOKEN", action: accessToken.clear)
                    .disabled(!hasToken)
                    .accessibilityIdentifier("auth.clearToken")
                if accessToken.isFetching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            if let failure = accessToken.failure {
                Text("AUTH_OAUTH2_TOKEN_FAILED")
                    .bold()
                    .accessibilityIdentifier("auth.tokenFailure")
                Text(verbatim: failure)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("auth.tokenFailureReason")
            }
        }
    }

    private var hasToken: Bool {
        if case .token = accessToken.status {
            true
        } else {
            false
        }
    }

    @ViewBuilder
    private func tokenStatus(at now: Date) -> some View {
        switch accessToken.status {
        case .loading:
            ProgressView()
                .controlSize(.small)
        case .none:
            Text("AUTH_OAUTH2_NO_TOKEN")
        case .token(let token):
            switch token.state(at: now) {
            case .expires(let expiresAt):
                Text(
                    "AUTH_OAUTH2_TOKEN_EXPIRES \(expiresAt.formatted(.relative(presentation: .named, unitsStyle: .wide)))"
                )
            case .noExpiry:
                Text("AUTH_OAUTH2_TOKEN_NO_EXPIRY")
            case .expired:
                Text("AUTH_OAUTH2_TOKEN_EXPIRED")
            }
        }
    }

    private func oauth2Field<Value>(_ field: WritableKeyPath<OAuth2Draft, Value>) -> Binding<Value> {
        Binding {
            draft.oauth2[keyPath: field]
        } set: { value in
            update { $0.oauth2[keyPath: field] = value }
        }
    }

}

extension OAuth2GrantType {

    var title: LocalizedStringKey {
        switch self {
        case .clientCredentials: "AUTH_OAUTH2_GRANT_CLIENT_CREDENTIALS"
        case .authorizationCode: "AUTH_OAUTH2_GRANT_AUTHORIZATION_CODE"
        case .authorizationCodeWithPKCE: "AUTH_OAUTH2_GRANT_AUTHORIZATION_CODE_PKCE"
        case .implicit: "AUTH_OAUTH2_GRANT_IMPLICIT"
        case .passwordCredentials: "AUTH_OAUTH2_GRANT_PASSWORD"
        }
    }

}
