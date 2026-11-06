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

    mutating func collection(
        _ postman: PostmanCollection,
        avoiding existingNames: Set<String>
    ) -> RequestCollection {
        countScripts(postman.events)
        countDescription(postman.info.description)

        return RequestCollection(
            name: ImportedName.unique(ImportedName.given(postman.info.name), avoiding: existingNames),
            auth: auth(postman.auth, whenUnset: .none),
            variables: variables(postman.variables),
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

    mutating func keyValues(_ rows: [PostmanKeyValue]) -> [KeyValue] {
        var keyValues: [KeyValue] = []
        for row in rows {
            countDescription(row.description)
            keyValues.append(KeyValue(key: row.key ?? "", value: row.value ?? "", isEnabled: row.isEnabled))
        }
        return keyValues
    }

    /// Takes each place one thing's description can sit, because a request has two.
    mutating func countDescription(_ descriptions: PostmanDescription?...) {
        if descriptions.contains(where: { $0?.content?.isBlank == false }) {
            skipped.descriptions += 1
        }
    }

    private mutating func countScripts(_ events: [PostmanEvent]) {
        skipped.scripts += events.count { event in
            event.script?.exec.contains { !$0.isBlank } == true
        }
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
        imported.folders += 1
        skipped.folderVariables += postman.variables.count
        countScripts(postman.events)
        countDescription(postman.description)

        return Folder(
            name: ImportedName.given(postman.name),
            auth: auth(postman.auth, whenUnset: .inherit),
            children: items(postman.items)
        )
    }

    private mutating func request(_ postman: PostmanRequestItem) -> Request {
        imported.requests += 1
        countScripts(postman.events)
        countDescription(postman.description, postman.request.description)
        let url = postman.request.url

        return Request(
            name: ImportedName.given(postman.name),
            method: postman.request.method.map(HTTPMethod.init(rawValue:)) ?? .get,
            urlTemplate: url?.template ?? "",
            queryParameters: keyValues(url?.query ?? []),
            pathParameters: pathParameters(url?.variables ?? []),
            headers: keyValues(postman.request.headers),
            body: body(postman.request.body),
            auth: auth(postman.request.auth, whenUnset: .inherit),
            variables: variables(postman.variables)
        )
    }

    private mutating func pathParameters(_ variables: [PostmanVariable]) -> [KeyValue] {
        var parameters: [KeyValue] = []
        for variable in variables {
            countDescription(variable.description)
            parameters.append(KeyValue(
                key: variable.key ?? variable.id ?? "",
                value: variable.value?.text ?? "",
                isEnabled: variable.isEnabled
            ))
        }
        return parameters
    }

}

nonisolated struct PendingSecret {

    let reference: SecretReference
    let value: String

}
