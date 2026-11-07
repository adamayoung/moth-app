//  RequestCodeModel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import AppKit
import MothCore
import MothImport
import Observation
import OSLog

struct GenerateCodeTarget: Identifiable {

    let id: Request.ID
    let code: GeneratedCode

}

/// One window's code generation. It holds no `SecretStore`, so nothing it copies can hold a secret.
@Observable
final class RequestCodeModel {

    typealias Generate = @MainActor (Request.ID, RequestDraft?, CollectionTree) async throws -> GeneratedCode

    var presented: GenerateCodeTarget?
    var hasFailed = false

    private let clipboard: Clipboard
    private let generate: Generate

    init(clipboard: Clipboard, generate: @escaping Generate) {
        self.clipboard = clipboard
        self.generate = generate
    }

    /// With no `draft`, generates from the stored request. Both go the way Send does, which replaces `.inherit`.
    convenience init(dataModel: DataModel, activeEnvironment: ActiveEnvironment, clipboard: Clipboard) {
        let generator = CodeGenerator()
        self.init(clipboard: clipboard) { id, draft, tree in
            let context = try dataModel.sendContext(for: id, in: tree, environment: activeEnvironment.id)
            let outgoing = try (draft ?? RequestDraft(context.request)).outgoing(from: context.request, in: tree)
            return try await generator.code(for: outgoing.request, scopes: context.scopes)
        }
    }

    /// New on every use, because previews share one process and one would otherwise show another's code.
    static var preview: RequestCodeModel {
        RequestCodeModel(clipboard: Clipboard(pasteboard: .withUniqueName())) { _, _, _ in
            GeneratedCode(curl: "", swift: "")
        }
    }

    func copyCURL(_ id: Request.ID, draft: RequestDraft?, tree: CollectionTree) async {
        if let code = await code(for: id, draft: draft, tree: tree) {
            copy(code.curl)
        }
    }

    func presentCode(for id: Request.ID, draft: RequestDraft?, tree: CollectionTree) async {
        if let code = await code(for: id, draft: draft, tree: tree) {
            presented = GenerateCodeTarget(id: id, code: code)
        }
    }

    func copy(_ text: String) {
        clipboard.copy(text)
    }

    private func code(for id: Request.ID, draft: RequestDraft?, tree: CollectionTree) async -> GeneratedCode? {
        do {
            return try await generate(id, draft, tree)
        } catch {
            Logger.code.error("Generating code failed: \(String(describing: error), privacy: .private)")
            hasFailed = true
            return nil
        }
    }

}
