//  CookiesModel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import Observation
import OSLog

/// One window's Cookies sheet, over the jar of the workspace the app shows.
@Observable
final class CookiesModel {

    struct Domain: Identifiable, Equatable {

        let name: String
        let cookies: [Cookie]

        var id: String {
            name
        }

    }

    var isPresented = false
    var isConfirmingDeleteAll = false
    var selection: Cookie.Identity?
    private(set) var domains: [Domain] = []
    @ObservationIgnored private let jar: () -> WorkspaceCookieJar?

    init(jar: @escaping () -> WorkspaceCookieJar?) {
        self.jar = jar
    }

    convenience init(dataModel: DataModel, cookieJars: CookieJars) {
        self.init { dataModel.workspaceID.map(cookieJars.jar(for:)) }
    }

    var selectedCookie: Cookie? {
        domains.lazy.flatMap(\.cookies).first { $0.identity == selection }
    }

    func open() async {
        selection = nil
        await load()
        isPresented = true
    }

    func deleteSelected() async {
        guard let deleted = selection else {
            return
        }
        selection = nil
        await delete([deleted])
    }

    func deleteCookies(in domain: String) async {
        let identities = domains.first { $0.name == domain }?.cookies.map(\.identity) ?? []
        if let selection, identities.contains(selection) {
            self.selection = nil
        }
        await delete(Set(identities))
    }

    func confirmDeleteAll() {
        isConfirmingDeleteAll = true
    }

    func deleteAll() async {
        selection = nil
        do {
            try await jar()?.deleteAll()
        } catch {
            Logger.cookies.error("Deleting all cookies failed: \(String(describing: error), privacy: .public)")
        }
        await load()
    }

    private func delete(_ identities: Set<Cookie.Identity>) async {
        do {
            try await jar()?.delete(identities)
        } catch {
            Logger.cookies.error("Deleting cookies failed: \(String(describing: error), privacy: .public)")
        }
        await load()
    }

    private func load() async {
        let cookies = await jar()?.all ?? []
        domains = Dictionary(grouping: cookies, by: \.domain)
            .map { name, cookies in
                Domain(name: name, cookies: cookies.sorted { ($0.name, $0.path) < ($1.name, $1.path) })
            }
            .sorted { $0.name < $1.name }
    }

}
