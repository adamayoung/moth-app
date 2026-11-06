//  PostmanMapper.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import PostmanKit

nonisolated struct PostmanMapper {

    var skipped = PostmanSkippedCounts()

    mutating func collection(_ postman: PostmanCollection) -> RequestCollection {
        RequestCollection(name: postman.info.name, children: items(postman.items))
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
        Folder(name: postman.name ?? "", children: items(postman.items))
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
            body: body(postman.request.body)
        )
    }

    func keyValues(_ rows: [PostmanKeyValue]) -> [KeyValue] {
        rows.map { KeyValue(key: $0.key ?? "", value: $0.value ?? "", isEnabled: $0.isEnabled) }
    }

    private func pathParameters(_ variables: [PostmanVariable]) -> [KeyValue] {
        variables.map { KeyValue(key: $0.key ?? $0.id ?? "", value: $0.value?.text ?? "", isEnabled: $0.isEnabled) }
    }

}
