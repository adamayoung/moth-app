//  CookiesSheet.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import HTTPKit
import MothCore
import SwiftUI

/// A row never shows a value: it is a credential as often as not, so only the selected cookie's is on screen.
struct CookiesSheet: View {

    @Bindable var model: CookiesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COOKIES_TITLE")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if model.domains.isEmpty {
                ContentUnavailableView {
                    Text("COOKIES_EMPTY")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cookieList
                selectedValue
            }

            buttons
        }
        .padding()
        .frame(minWidth: 560, minHeight: 420)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cookies")
        .alert("COOKIES_DELETE_ALL_TITLE", isPresented: $model.isConfirmingDeleteAll) {
            Button("COOKIES_DELETE_ALL_CONFIRM", role: .destructive) {
                Task { await model.deleteAll() }
            }
            Button("COOKIES_CANCEL", role: .cancel) {}
        } message: {
            Text("COOKIES_DELETE_ALL_MESSAGE")
        }
    }

    private var cookieList: some View {
        List(selection: $model.selection) {
            ForEach(model.domains) { domain in
                Section {
                    ForEach(domain.cookies, id: \.identity) { cookie in
                        CookieRow(cookie: cookie)
                    }
                } header: {
                    domainHeader(domain.name)
                }
            }
        }
        .accessibilityIdentifier("cookies.list")
        .onDeleteCommand {
            Task { await model.deleteSelected() }
        }
    }

    private func domainHeader(_ name: String) -> some View {
        HStack {
            Text(verbatim: name)
            Spacer()
            Button {
                Task { await model.deleteCookies(in: name) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(Text("COOKIES_DELETE_DOMAIN_\(name)"))
            .accessibilityLabel(Text("COOKIES_DELETE_DOMAIN_\(name)"))
            .accessibilityIdentifier("cookies.deleteDomain.\(name)")
        }
    }

    @ViewBuilder
    private var selectedValue: some View {
        if let cookie = model.selectedCookie {
            VStack(alignment: .leading, spacing: 4) {
                Text("COOKIES_VALUE")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(verbatim: cookie.value)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(3)
                    .accessibilityIdentifier("cookies.value")
            }
        } else {
            Text("COOKIES_NO_SELECTION")
                .foregroundStyle(.secondary)
        }
    }

    private var buttons: some View {
        HStack {
            Button("COOKIES_DELETE") {
                Task { await model.deleteSelected() }
            }
            .disabled(model.selection == nil)
            .accessibilityIdentifier("cookies.delete")

            Button("COOKIES_DELETE_ALL") {
                model.confirmDeleteAll()
            }
            .disabled(model.domains.isEmpty)
            .accessibilityIdentifier("cookies.deleteAll")

            Spacer()

            Button("COOKIES_DONE") {
                model.isPresented = false
            }
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("cookies.done")
        }
    }

}

private struct CookieRow: View {

    let cookie: Cookie

    var body: some View {
        HStack {
            Text(verbatim: cookie.name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: cookie.path)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            expiry
                .foregroundStyle(.secondary)
                .frame(width: 170, alignment: .leading)
        }
    }

    private var expiry: Text {
        if let expiresAt = cookie.expiresAt {
            Text(expiresAt, format: .dateTime.year().month().day().hour().minute())
        } else {
            Text("COOKIES_EXPIRES_SESSION")
        }
    }

}

@MainActor
private func previewModel(cookies: [Cookie]) -> CookiesModel? {
    let workspace = Workspace()
    guard let dataModel = try? DataModel.inMemory(seed: workspace) else {
        return nil
    }
    let jars = CookieJars(
        writer: dataModel.writer,
        secretStore: InMemorySecretStore(),
        seed: [workspace.id: cookies]
    )
    return CookiesModel(dataModel: dataModel, cookieJars: jars)
}

#Preview("Cookies") {
    if let model = previewModel(cookies: SeedData.cookies) {
        CookiesSheet(model: model)
            .task {
                await model.open()
                model.selection = SeedData.cookies.first?.identity
            }
    }
}

#Preview("No Cookies") {
    if let model = previewModel(cookies: []) {
        CookiesSheet(model: model)
    }
}
