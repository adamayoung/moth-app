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

extension Array {

    var only: Element? {
        count == 1 ? first : nil
    }

}
