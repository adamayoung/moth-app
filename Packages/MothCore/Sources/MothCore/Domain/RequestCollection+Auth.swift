//  RequestCollection+Auth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated extension RequestCollection {

    /// Assign this to the request before resolving it: the resolver fetches secrets only for the auth it is given.
    func effectiveAuth(of request: Request) -> Auth {
        guard request.auth == .inherit else {
            return request.auth
        }

        guard let folderAuths = Self.folderAuths(leadingTo: request.id, in: children) else {
            return .none
        }

        return ([auth] + folderAuths).last { $0 != .inherit } ?? .none
    }

    private static func folderAuths(leadingTo requestID: UUID, in items: [CollectionItem]) -> [Auth]? {
        for item in items {
            switch item.node {
            case .request(let request):
                if request.id == requestID {
                    return []
                }
            case .folder(let folder):
                if let path = folderAuths(leadingTo: requestID, in: folder.children) {
                    return [folder.auth] + path
                }
            }
        }

        return nil
    }

}
