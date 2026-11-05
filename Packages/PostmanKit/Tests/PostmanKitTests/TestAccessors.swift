//  TestAccessors.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import PostmanKit

extension PostmanItem {

    var folder: PostmanFolder? {
        if case .folder(let folder) = self {
            return folder
        }
        return nil
    }

    var requestItem: PostmanRequestItem? {
        if case .request(let item) = self {
            return item
        }
        return nil
    }

}

extension [PostmanItem] {

    var requestItems: [PostmanRequestItem] {
        flatMap { item -> [PostmanRequestItem] in
            switch item {
            case .folder(let folder): folder.items.requestItems
            case .request(let request): [request]
            }
        }
    }

    func request(named name: String) -> PostmanRequest? {
        requestItems.first { $0.name == name }?.request
    }

}

extension PostmanCollection {

    func request(named name: String) -> PostmanRequest? {
        items.request(named: name)
    }

}

extension Array {

    var only: Element? {
        count == 1 ? first : nil
    }

}
