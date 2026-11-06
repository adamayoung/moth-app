//  PostmanMapper.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import PostmanKit

nonisolated struct PostmanMapper {

    var imported = PostmanImportedCounts()
    var skipped = PostmanSkippedCounts()
    private(set) var pendingSecrets: [PendingSecret] = []

    mutating func collection(_ postman: PostmanCollection) -> RequestCollection {
        RequestCollection(
            name: postman.info.name,
            auth: auth(postman.auth, whenUnset: .none),
            children: items(postman.items)
        )
    }

    /// A value the file doesn't hold saves nothing, so Moth reports the secret as missing.
    mutating func secret(_ value: String?) -> SecretReference {
        let reference = SecretReference()
        if let value {
            pendingSecrets.append(PendingSecret(reference: reference, value: value))
        }
        return reference
    }

    /// A `nil` reference means the kind has no such credential, and Postman writes empty fields for those.
    mutating func optionalSecret(_ value: String?) -> SecretReference? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return secret(value)
    }

    private mutating func items(_ postman: [PostmanItem]) -> [CollectionItem] {
        var items: [CollectionItem] = []
        for (index, item) in postman.enumerated() {
            switch item {
            case .folder(let folder):
                items.append(CollectionItem(sortOrder: index, node: .folder(self.folder(folder))))
            case .request(let request):
                items.append(CollectionItem(sortOrder: index, node: .request(self.request(request))))
            }
        }
        return items
    }

    private mutating func folder(_ postman: PostmanFolder) -> Folder {
        Folder(
            name: postman.name ?? "",
            auth: auth(postman.auth, whenUnset: .inherit),
            children: items(postman.items)
        )
    }

    private mutating func request(_ postman: PostmanRequestItem) -> Request {
        let url = postman.request.url

        return Request(
            name: postman.name ?? "",
            method: postman.request.method.map(HTTPMethod.init(rawValue:)) ?? .get,
            urlTemplate: url?.template ?? "",
            queryParameters: keyValues(url?.query ?? []),
            pathParameters: pathParameters(url?.variables ?? []),
            headers: keyValues(postman.request.headers),
            body: body(postman.request.body),
            auth: auth(postman.request.auth, whenUnset: .inherit)
        )
    }

    func keyValues(_ rows: [PostmanKeyValue]) -> [KeyValue] {
        rows.map { KeyValue(key: $0.key ?? "", value: $0.value ?? "", isEnabled: $0.isEnabled) }
    }

    private func pathParameters(_ variables: [PostmanVariable]) -> [KeyValue] {
        variables.map { KeyValue(key: $0.key ?? $0.id ?? "", value: $0.value?.text ?? "", isEnabled: $0.isEnabled) }
    }

}

nonisolated struct PendingSecret {

    let reference: SecretReference
    let value: String

}
